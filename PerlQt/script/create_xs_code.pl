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
    GetOptions(
        'template=s'   => \$template_dir, 
        'typemap=s'    => \@typemap_files, 
        'packagemap=s' => \$packagemap_file, 
        'o|outoput=s'  => \$xs_file, 
    );
    usage() unless @ARGV >= 1;
    
    my %f = ();
    foreach my $f (@ARGV) {
        my @f = split /\./, $f;
        shift @f;
        my $k = join(".", @f);
        $f{$k} = $f;
    }
    
    # open source files
    # class name, mod name, class hierarchy
    croak "no meta file found for $xs_file" unless $f{meta};
    my $meta    = load_yaml($f{meta});
    # public methods
    #carp "no public file found for $xs_file" unless grep { /public$/ } keys %f;
    my $publics = [];
    foreach my $k (grep { /public$/ } keys %f) {
        my $methods = load_yaml($f{$k});
        push @$publics, @$methods;
    }
    exit 0 if @$publics == 0;
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
        next if $t =~ /^T_/o;
        if ($typedef->{$t} =~ /^T_/o) {
            if ($typedef->{$t} =~ /^T_FPOINTER/) {
                $typemap->{$t} = 'T_FPOINTER';
            }
            else {
                $typemap->{$t} = $typedef->{$t};
            }
        }
    }
    # global packagemap
    my $packagemap = load_yaml($packagemap_file);
    my $subst_with_fullname = sub {
        my ( $type, ) = @_;
        
        foreach my $k (keys %$localtype) {
            $type =~ s/(?<!\:)\b\Q$k\E/$localtype->{$k}/e;
        }
        return $type;
    };
    
    # loop into each public method, group by name
    my $pub_method_by_name = {};
    foreach my $i (@$publics) {
        # convert relevant field key to lowcase
        # no conflict with template commands
        my $name         = delete $i->{NAME};
        $i->{parameters} = exists $i->{PARAMETER} ? 
          delete $i->{PARAMETER} : [];
        $i->{return}     = delete $i->{RETURN} if exists $i->{RETURN};
        # substitude with full typename for entries in typemap
        if (exists $i->{return}) {
            $i->{return} = $subst_with_fullname->($i->{return});
            $i->{return} =~ s/^\s*static\b//o;
            # FIXME: skip template class for now
            next if $i->{return} =~ /</io;
        }
        for (my $j = 0; $j < @{$i->{parameters}}; $j++) {
            my $p = $i->{parameters}->[$j];
            $p->{name} = exists $p->{NAME} ? delete $p->{NAME} : "arg$j";
            $p->{type} = delete $p->{TYPE};
            $p->{type} = $subst_with_fullname->($p->{type});
            $p->{default} = delete $p->{DEFAULT_VALUE} if exists $p->{DEFAULT_VALUE};
            # FIXME: skip template class for now
            next if $p->{type} =~ /</io;
        }
        push @{$pub_method_by_name->{$name}}, $i;
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
    foreach my $name (keys %$pub_method_by_name) {
        my $new_methods = [];
        
        foreach my $method (@{$pub_method_by_name->{$name}}) {
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
        $pub_method_by_name->{$name} = [
            sort { scalar(@{$a->{parameters}}) <=>
                     scalar(@{$b->{parameters}}) } 
              @$new_methods
        ];
    }
    
    # generate xs file from template
    my $template = Template::->new({
        INCLUDE_PATH => $template_dir, 
        INTERPOLATE  => 1,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 0,
        TRIM         => 1,
        EVAL_PERL    => 1,
    });
    my $out = '';
    my $var = {
        my_cclass     => $meta->{NAME}, 
        my_type       => $meta->{type}, 
        my_module     => $meta->{MODULE}, 
        my_package    => $packagemap->{$meta->{NAME}}, 
        my_method     => $pub_method_by_name, 
        my_typemap    => $typemap, 
        my_packagemap => $packagemap, 
    };
    $template->process('body.tt2', $var, \$out) or 
      croak $template->error. "\n";
    print STDERR $out, "\n";
    
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
