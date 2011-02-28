#! /usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw(GetOptions);

use YAML::Syck qw/Load Dump/;
use Template;

my %OPERATOR_MAP = (
    '='   => 'assign',
    '+'   => 'add',
    '-'   => 'min',
    '*'   => 'mul',
    '/'   => 'div',
    '%'   => 'mod',
    '++'  => 'incr',
    '--'  => 'decr',
    '=='  => 'equal_to',
    '!='  => 'not_equal',
    '<'   => 'lt',
    '>'   => 'gt',
    '<='  => 'le',
    '>='  => 'ge',
    '!'   => 'not',
    '&&'  => 'and',
    '||'  => 'or',
    '~'   => 'bit_not',
    '&'   => 'bit_and',
    '|'   => 'bit_or',
    '^'   => 'bit_xor',
    '<<'  => 'bit_left',
    '>>'  => 'bit_right',
    '+='  => 'add_assign',
    '-='  => 'min_assign',
    '*='  => 'mul_assign',
    '/='  => 'div_assign',
    '%='  => 'mod_assign',
    '&='  => 'bit_and_assign',
    '|='  => 'bit_or_assign',
    '^='  => 'bit_not_assign',
    '<<=' => 'bit_left_assign',
    '>>=' => 'bit_right_assign',
    '[]'  => 'array',
    '()'  => 'funct',
    # FIXME
    #'*'   => 'deref',
    #'&'   => 'ref',
    '->'  => 'mem_of_ptr',
    '.'   => 'mem_of_obj',
    ','   => 'comma',
    'new[]'    => 'alloc_array',
    'delete[]' => 'del_array',
);

=head1 DESCRIPTION

Create <module>.xs accordingly to 
04group/<module>.{meta, function.public, enum} and 
05typemap/<module>.typemap

.enum and .typemap are optional

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 -template <template_dir> -typemap <typemap> -packagemap <packagemap> <module>.* <module.xs>
EOU
    exit 1;
}

sub load_yaml {
    my $path = shift;
    local ( *YAML, );
    open YAML, "<", $path or croak "cannot open file to read: $!";
    my $cont = do { local $/; <YAML> };
    close YAML;
    return Load($cont);
}

sub main {
    my $template_dir    = '';
    my @typemap_files   = ();
    my $packagemap_file = '';
    my $xs_file         = '';
    my $out             = '';
    GetOptions(
        'template=s'   => \$template_dir, 
        'typemap=s'    => \@typemap_files, 
        'packagemap=s' => \$packagemap_file, 
        'o|outoput=s'  => \$xs_file, 
    );
    usage() unless @ARGV >= 1;
    
    my %f = ();
    foreach my $p (@ARGV) {
        my $f = (split /\//, $p)[-1];
        my @f = split /\./, $f;
        shift @f;
        my $k = join(".", @f);
        $f{$k} = $p;
    }
    
    # open source files
    # class name, mod name, class hierarchy
    croak "no meta file found for $xs_file" unless $f{meta};
    my $meta    = load_yaml($f{meta});
    if ($meta->{TYPE} !~ /^(?:class|struct)$/o) {
        print STDERR "skip $f{meta}, not a class or struct\n";
        goto WRITE_FILE;
    }
    
    # public methods
    #carp "no public file found for $xs_file" unless grep { /public$/ } keys %f;
    my $publics = [];
    foreach my $k (grep { /public$/ } keys %f) {
        my $methods = load_yaml($f{$k});
        push @$publics, @$methods;
    }
    if (@$publics == 0) {
        print STDERR "skip $f{meta}, no public method\n";
        goto WRITE_FILE;
    }
    # class localtype
    my $localtype = exists $f{typemap} ? load_yaml($f{typemap}) : {};
    # typedef info
    my $typedef = exists $f{typedef} ? load_yaml($f{typedef}) : {};
    # global typemap
    my $typemap = {};
    foreach my $f (@typemap_files) {
        # open my $F, $f or croak "cannot open file to read: $!";
        # while (<$F>) {
        #     next if /^\s*#/o;
        #     last if /^(?:INPUT|OUTPUT)$/o;
        #     chomp;
        #     next if !$_;
        #     my ( $k, $v ) = split /(?: {2,}|\t+)/, $_, 2;
        #     $typemap->{$k} = $v;
        # }
        my $map = load_yaml($f);
        foreach my $k (keys %$map) {
            $typemap->{$k} = $map->{$k};
        }
    }
    # add hidden typemap (for function pointer and enum)
    # in class typedef file
    foreach my $t (keys %$typedef) {
        if ($t =~ /^T_FPOINTER/) {
            $typemap->{$t} = 'T_FPOINTER';
        }
    }
    # global packagemap
    my $packagemap = load_yaml($packagemap_file);
    my $subst_with_fullname = sub {
        my ( $type, ) = @_;
        
        # translate local typedef to full class name
        if (exists $localtype->{$type} and $type !~ /^T_FPOINTER_/o) {
            $type = $localtype->{$type};
        }
        # foreach my $k (keys %$localtype) {
        #     $type =~ s/(?<!\:)\b\Q$k\E\b/$localtype->{$k}/e;
        # }
        # foreach my $t (keys %$typedef) {
        #     next if $t =~ /^T_/o;
        #     if ($typedef->{$t} !~ /^T_/o) {
        #         $type =~ s/(?<!\:)\b\Q$t\E\b/$typedef->{$t}/e;
        #     }
        #     $type =~ s/(?<!\:)\b\Q$t\E\b/$meta->{NAME}. '::'. $t/e;
        # }
        return $type;
    };
    
    # loop into each public method, group by name
    my $pub_methods_by_name = {};
    METHOD_LOOP:
    foreach my $i (@$publics) {
        # convert relevant field key to lowcase
        # no conflict with template commands
        my $name         = delete $i->{NAME};
        if ($i->{operator}) {
            my $name2 = $name;
            if ($name2 =~ /^operator\s(.+)$/) {
                # operator int => operator_int
                $i->{return} = $1;
                $name2 =~ s/\s+/_/go;
                $name2 =~ s/\*/ptr/go;
                $name2 =~ s/\&/ref/go;
            }
            else {
                my ( $op ) = $name2 =~ /^operator(.+)$/o;
                if (exists $OPERATOR_MAP{$op}) {
                    $name2 = 'operator_'. $OPERATOR_MAP{$op};
                }
                else {
                    print STDERR "no operator op match: operator$op\n";
                }
            }
            $i->{name2} = $name2;
        }
        $i->{parameters} = exists $i->{PARAMETER} ? 
          delete $i->{PARAMETER} : [];
        $i->{return}     = delete $i->{RETURN} if exists $i->{RETURN};
        # substitude with full typename for entries in typemap
        if (exists $i->{return}) {
            $i->{return} = $subst_with_fullname->($i->{return});
            $i->{return} =~ s/^\s*static\b//o;
            # FIXME: skip template class for now
            next METHOD_LOOP if $i->{return} =~ /</io;
        }
        my $param_num = @{$i->{parameters}};
        # handle foo(void)
        if ($param_num == 1 and $i->{parameters}->[0]->{TYPE} eq 'void') {
            splice @{$i->{parameters}}, 0, 1;
        }
        PARAM_LOOP:
        for (my $j = 0; $j < $param_num; $j++) {
            my $p = $i->{parameters}->[$j];
            $p->{name} = exists $p->{NAME} ? delete $p->{NAME} : "arg$j";
            $p->{type} = delete $p->{TYPE};
            $p->{type} = $subst_with_fullname->($p->{type});
            if (exists $p->{DEFAULT_VALUE}) {
                $p->{default} = delete $p->{DEFAULT_VALUE};
                if (exists $typemap->{$p->{type}} and
                      $typemap->{$p->{type}} eq 'T_ENUM') {
                    if ($p->{default} !~ /\:\:/o) {
                        # stamp with class name
                        my @type = split /\:\:/, $p->{type};
                        if (@type > 1) {
                            pop @type;
                            $p->{default} = join('::', @type, $p->{default});
                        }
                    }
                }
                # a bug in the parser, default value ' ' becomes ''
                $p->{default} =~ s/\(''\)/(' ')/o;
                $p->{default} = q(' ') if $p->{default} eq q('');
            }
            # FIXME: skip template class for now
            next METHOD_LOOP if $p->{type} =~ /</io;
            # transform sprintf(format,...) to sprintf(char *)
            # the implementation will be:
            # 1) in perl code, call perl's sprintf
            # 2) return SvPV to XS code
            if ($p->{type} eq '...') {
                if ($param_num == 2) {
                    # sprint(format, ...)
                    splice @{$i->{parameters}}, 0, $param_num, {
                        name => 'string',
                        type => 'char *',
                    };
                }
                elsif ($param_num == 1) {
                    # foo(...)
                    next METHOD_LOOP;
                }
            }
        }
        push @{$pub_methods_by_name->{$name}}, $i;
    }
    # map method with default param value
    # foo(int, int = 0, int = 0)
    # into:
    # foo(int, int, 0  )
    # foo(int, int, int)
    # foo(int, 0  , 0)
    # foo(int, int, 0)
    my $cb_clone_method = sub {
        my ( $method, ) = @_;
        
        my $clone = {};
        $clone->{parameters} = [];
        foreach my $k (keys %$method) {
            if ($k eq 'parameters') {
                for (my $i = 0; $i < @{$method->{parameters}}; $i++) {
                    foreach my $p (keys %{$method->{parameters}->[$i]}) {
                        $clone->{parameters}->[$i]->{$p} =
                          $method->{parameters}->[$i]->{$p};
    }
                }
            }
            else {
                $clone->{$k} = $method->{$k};
            }
        }
        return $clone;
    };
    foreach my $name (keys %$pub_methods_by_name) {
        my $new_methods = [];
        
        foreach my $method (@{$pub_methods_by_name->{$name}}) {
            my $cloned = 0;
            for (my $i = $#{$method->{parameters}}; $i >= 0; $i--) {
                my $p = $method->{parameters}->[$i];
                if (exists $p->{default}) {
                    my $clone = $cb_clone_method->($method);
                    for (my $j = $i - 1; $j >= 0; $j--) {
                        delete $clone->{parameters}->[$j]->{default} if 
                          exists $clone->{parameters}->[$j]->{default};
                    }
                    push @$new_methods, $clone;
                    $clone = $cb_clone_method->($method);
                    for (my $j = $i; $j >= 0; $j--) {
                        delete $clone->{parameters}->[$j]->{default} if
                          exists $clone->{parameters}->[$j]->{default};
                    }
                    push @$new_methods, $clone;
                    $cloned = 1;
                }
            }
            if (!$cloned) {
                push @$new_methods, $method;
            }
        }
        $pub_methods_by_name->{$name} = [
            sort { scalar(@{$a->{parameters}}) <=>
                     scalar(@{$b->{parameters}}) } 
              @$new_methods
        ];
    }
    
    # generate xs file from template
    my $template = Template::->new({
        INCLUDE_PATH => $template_dir, 
        INTERPOLATE  => 0,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 0,
        TRIM         => 1,
        EVAL_PERL    => 1,
    });
    # workaround a bug in ttk when a key of hash is 'keys'
    # it gets wrong
    my $mem_methods = [];
    my $cname = (split /\:\:/, $meta->{NAME})[-1];
    foreach my $m (sort keys %$pub_methods_by_name) {
        next if $m eq $cname;
        next if $m eq '~'. $cname;
        push @$mem_methods, $m;
    }
    my $abstract_class = 0;
    if (exists $meta->{PROPERTY}) {
        $abstract_class = 1 if grep { $_ eq 'abstract' } @{$meta->{PROPERTY}};
    }
    #use Data::Dumper;
    #print Data::Dumper::Dumper($pub_methods_by_name);
    my $var = {
        my_cclass          => $meta->{NAME}, 
        my_type            => $meta->{type}, 
        my_module          => $meta->{MODULE}, 
        my_package         => $packagemap->{$meta->{NAME}}, 
        my_file            => $meta->{FILE},
        my_methods         => $mem_methods,
        my_methods_by_name => $pub_methods_by_name, 
        my_typemap         => $typemap, 
        my_packagemap      => $packagemap, 
        my_abstract        => $abstract_class,
    };
    $template->process('body.tt2', $var, \$out) or 
      croak $template->error. "\n";
WRITE_FILE:
    if ($xs_file) {
        open my $F, '>', $xs_file or 
          croak "cannot open file to write: $!";
        print $F $out;
        close $F or croak "cannot save to file: $!";
    }
    else {
        print $out, "\n";
    }
    
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
