#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use YAML ();
use File::Spec ();
use Config;
use Parse::RecDescent ();
# make sure typemap exists
use ExtUtils::MakeMaker ();

=head1 DESCRIPTION

Create typemap according to all relevant source: 

<module>.{function.public, function.protected, signal, slot.public,
slot.protected} and <module>.typedef

B<NOTE>: Connect each involved C++ type (either function parameter
type or function return type) to known typemap slot; Record unknown
ones into typemap.unknown

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <module.conf> <typemap.ignore> <typemap.simple> <typemap.dep> <in_xscode_dir> [<out_typemap>]
EOU
    exit 1;
}

# for AUTOLOAD
# prototype required
# FIXME: ref of ptr, ptr of ref, ptr of ptr
sub PTR(;$) { 0 }
sub REF(;$) { 1 }
sub const($) {
    my $entry = shift;
    $entry->{const} = 1;
    return $entry;
}
sub unsigned($) {
    my $entry = shift;
    $entry->{unsigned} = 1;
    return $entry;
}
sub signed($) {
    my $entry = shift;
    $entry->{signed} = 1;
    return $entry;
}
# mask CORE::int
*CORE::GLOBAL::int = sub {};

# internal use
our $AUTOLOAD;
our $TYPE;

our $NAMESPACE_DELIMITER = '__';
our $DEFAULT_NAMESPACE   = '';
our $CURRENT_NAMESPACE   = '';

our %TYPE_DICTIONARY     = ();
our %SIMPLE_TYPEMAP      = ();
our %GLOBAL_TYPEMAP      = ();
our %IGNORE_TYPEMAP      = ();

=over

=item _load_yaml

Internal use. Load a YAML-ish file and return its yaml-ed content.

=back

=cut

sub _load_yaml {
    my ( $f ) = @_;
    
    local ( *FILE, );
    open FILE, "<", $f or die "cannot open file: $!";
    my $cont = do { local $/; <FILE> };
    close FILE;
    my $hcont= YAML::Load($cont);
    return $hcont;
}

=over 

=item _read_typemap

Read supported type list inside a typemap file. Store each as a key of
hash passed-in. 

=back

=cut

sub _read_typemap {
    my ($typemap_file, $typemap, ) = @_;
    die "file $typemap_file not found" unless -f $typemap_file;
    local ( *TYPEMAP, );
    open TYPEMAP, "<", $typemap_file or die "cannot open file: $!";
    while (<TYPEMAP>) {
        chomp;
        last if m/^INPUT\s*$/o;
        next if m/^\#/io;
        next if m/^\s*$/io;
        next if m/^TYPEMAP\s*$/o;
        my @t = split /\s+/, $_;
        my $v = pop @t;
        my $k = join(" ", @t);
        $typemap->{$k} = $v;
    }
    close TYPEMAP;
}

sub main {
    usage() if @ARGV < 5;
    # FIXME: GetOpt::Long
    #        see script/gen_xscode_mk.pl
    my ( $module_dot_conf, $typemap_dot_ignore, $typemap_dot_simple, 
         $typemap_dot_dep, $in_xscode_dir, 
         $out ) = @ARGV;
    die "file $module_dot_conf not found" unless 
      -f $module_dot_conf;
    die "file $typemap_dot_ignore not found" unless 
      -f $typemap_dot_ignore;
    die "file $typemap_dot_simple not found" unless 
      -f $typemap_dot_simple;
    die "file $typemap_dot_dep not found" unless 
      -f $typemap_dot_dep;
    die "dir $in_xscode_dir not found" unless 
      -d $in_xscode_dir;
    
    my @typedef = ();
    my %member  = ();
    {
        local ( *TYPEMAP_DOT_DEP, );
        open TYPEMAP_DOT_DEP, "<", $typemap_dot_dep or 
          die "cannot open file: $!";
        while (<TYPEMAP_DOT_DEP>) {
            chomp;
            if (m/\.(function)\.(?:public|protected)$/o) {
                push @{$member{$1}}, $_;
            } elsif (m/\.(signal)$/o) {
                push @{$member{$1}}, $_;
            } elsif (m/\.(slot)\.(?:public|protected)$/o) {
                push @{$member{$1}}, $_;
            } elsif (m/\.typedef$/o) {
                push @typedef, $_;
            }
        }
        close TYPEMAP_DOT_DEP;
    }
    # get default namespace from module.conf
    my $hconf = _load_yaml($module_dot_conf);
    our $DEFAULT_NAMESPACE;
    $DEFAULT_NAMESPACE = $hconf->{default_namespace};
    # pre-cache relevant source to mask the whole process 
    # a transactional look
    # pre-cache all type info
    our %TYPE_DICTIONARY;
    foreach my $f (@typedef) {
        #print STDERR $f, "\n";
        my @f = File::Spec::->splitdir($f);
        ( my $n = $f[-1] ) =~ s/\.typedef$//o;
        $n =~ s/\_\_/::/gio;
        $TYPE_DICTIONARY{$n} = _load_yaml($f);
    }
    # pre-cache all function info
    my %method = ();
    foreach my $t (qw/function signal slot/) {
        foreach my $f (@{$member{$t}}) {
            my @f = File::Spec::->splitdir($f);
            ( my $n = $f[-1] ) =~ 
              s/\.\Q$t\E(?:\.(?:public|protected))?$//;
            $n =~ s/\_\_/::/gio;
            $method{$t}->{$n} = _load_yaml($f);
        }
    }
    # collect types
    my %type = ();
    foreach my $t (keys %method) {
        foreach my $n (keys %{$method{$t}}) {
            #print STDERR "name: ", $n, "\n";
            my $existing_type = {};
            foreach my $m (@{$method{$t}->{$n}}) {
                # param
                if (exists $m->{PARAMETER}) {
                    foreach my $p (@{$m->{PARAMETER}}) {
                        #print STDERR "type: ", $p->{TYPE}, "\n";
                        unless (exists $existing_type->{$p->{TYPE}}) {
                            push @{$type{$n}}, $p->{TYPE};
                            $existing_type->{$p->{TYPE}} = 1;
                        }
                    }
                }
                # return type
                if (exists $m->{RETURN}) {
                    unless (exists $existing_type->{$m->{RETURN}}) {
                        push @{$type{$n}}, $m->{RETURN};
                        $existing_type->{$m->{RETURN}} = 1;
                    }
                }
            }
        }
    }
    # generate typemap
    # transform each type string into a function expression
    # each function contribute certain information
    # which will finally construct a self-deterministic type structure
    # missing functions are handled by AUTOLOAD
    # lookup into %typedef
    # first the same namespace
    # then default namespace by $default_namespace
    my $known   = {};
    # in case failed lookup, push it into $unknown
    my $unknown = {};
    our ( %SIMPLE_TYPEMAP, %GLOBAL_TYPEMAP, %IGNORE_TYPEMAP, );
    # locate all known types from global typemap
    my $global_typemap_file = File::Spec::->catfile(
        $Config{privlib}, 'ExtUtils', 'typemap');
    _read_typemap($global_typemap_file, \%GLOBAL_TYPEMAP);
    # locate those types which should be ignored
    _read_typemap($typemap_dot_ignore, \%IGNORE_TYPEMAP);
    # locate simple types
    _read_typemap($typemap_dot_simple, \%SIMPLE_TYPEMAP);
    
    # const takes one additional parameter
    # a tiny Parse::RecDescent grammar to work on
    # grabbing const parameter
    my $const_grammar = q{
    start : next_const const_body const_remainder 
            { $main::TYPE = $item[1]->[1]. "( ". $item[2]. " ) ". $item[3]; }
            { if ($item[2] eq '') { 
                  # something like 'QMenuBar * const'
                  $main::TYPE = $item[1]->[0].", ".$main::TYPE;
              } else {
                  $main::TYPE = $item[1]->[0]. $main::TYPE;
              }
            }
    const_remainder        : m/^(.*)\Z/o      { $return = $1; } 
                           | { $return = ''; }
    next_const             : m/^(.*?)\b(const)\s*(?!\()/o 
                             { $return = [$1, $2]; } 
    const_body_simple      : m/([^()*&]+)/io { $return = $1; }  
    next_const_body_token  : m/([^()]+)/io   { $return = $1; } 
    const_body     : const_body_simple ...!'(' { $return = $item[1]; }
                   | const_body_loop           { $return = $item[1]; } 
                   |                           { $return = '';       }
    const_body_loop: next_const_body_token 
                     ( '(' <commit> const_body_loop ')' 
                       { $return = $item[1]. $item[3]. $item[4]; } 
                     | { $return = '' } ) 
                     { $return = $item[1]. $item[2]; }
    };
    my $parser = Parse::RecDescent::->new($const_grammar)
      or die "Bad grammar!";
    our $CURRENT_NAMESPACE;
    foreach my $n (keys %type) {
        #print STDERR "name: ", $n, "\n";
        $CURRENT_NAMESPACE = $n;
        foreach my $t (@{$type{$n}}) {
            our $TYPE = $t;
            # simply normalize
            $TYPE =~ s/^\s+//gio;
            $TYPE =~ s/\s+$//gio;
            $TYPE =~ s/\s+/ /gio;
            unless (exists $GLOBAL_TYPEMAP{$TYPE} or 
                      exists $SIMPLE_TYPEMAP{$TYPE} or 
                        exists $IGNORE_TYPEMAP{$TYPE}) {
                # transform
                # template to a function call
                # '<' => '('
                $TYPE =~ s/\</(/gio;
                # '>' => ')'
                $TYPE =~ s/\>/)/gio;
                #print STDERR "orig : ", $t, "\n";
                while ($TYPE =~ m/\bconst\s*(?!\()/o) {
                    defined $parser->start($TYPE) or die "Parse failed!";
                }
                #print STDERR "patch: ", $TYPE, "\n";
                # transform rule for coutinous (two or more) 
                # pointer ('*') or reference ('&')
                # * (*|&) => PTR (PTR|REF)
                # which means second will ALWAYS be a parameter of 
                # the first
                # for instance:
                # '* & *' => 'PTR( REF( PTR ))'
                # FIRST GREDDY IS IMPORTANT
                while ($TYPE =~ 
                         s{(.*(?<=(?:\*|\&))\s*)(\*|\&)}
                          {$1.'('. ($2 eq '*' ? ' PTR' : ' REF'. ')') }gei) {
                    1;
                }
                # leading or standalone pointer or reference
                # '*' => ', PTR'
                $TYPE =~ s/\*/, PTR/gio;
                # '&' => ', REF'
                $TYPE =~ s/\&/, REF/gio;
                # mask bareword as a function call without any
                # parameter
                # skip '(un)signed'
                $TYPE =~ s/\b(\w+)\b(?<!signed)(?!(?:\(|\:))/$1()/go;
                # '::' to $NAMESPACE_DELIMITER
                our $NAMESPACE_DELIMITER;
                $TYPE =~ s/\:\:/$NAMESPACE_DELIMITER/gio;
                #print $TYPE, "\n";
                $TYPE = '_transform( '. $TYPE .' )';
                eval $TYPE;
            }
        }
    }
    
    exit 0;
}

&main;

sub AUTOLOAD {
    our ( $DEFAULT_NAMESPACE, $NAMESPACE_DELIMITER, 
          %TYPE_DICTIONARY, $CURRENT_NAMESPACE, 
          %GLOBAL_TYPEMAP, %SIMPLE_TYPEMAP, );
    my $package = __PACKAGE__;
    ( my $autoload = $AUTOLOAD ) =~ s/^\Q$package\E(?:\:\:)?//o;
    my @namespace = split /\Q$NAMESPACE_DELIMITER\E/, $autoload;
    my $type = pop @namespace;
    if (@namespace) {
        my $namespace = join("::", @namespace);
        if (exists $TYPE_DICTIONARY{$namespace}->{$type}) {
        }
        elsif (exists $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type}) {
        }
        elsif (exists $GLOBAL_TYPEMAP{$type} or 
                 exists $SIMPLE_TYPEMAP{$type}) {
        }
        else {
            # unknown
            print join("::", @namespace, $type), "\n";
        }
    }
    else {
        if (exists $TYPE_DICTIONARY{$CURRENT_NAMESPACE}->{$type}) {
        }
        elsif (exists $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type}) {
        }
        elsif (exists $GLOBAL_TYPEMAP{$type} or 
                 exists $SIMPLE_TYPEMAP{$type}) {
        }
        else {
            # unknown
            print $CURRENT_NAMESPACE, ": ", $type, "\n";
        }
    }
}
