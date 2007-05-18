#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use YAML ();
use File::Spec ();
use Config;
# make sure typemap exists
use ExtUtils::MakeMaker ();

our $AUTOLOAD;

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
    my $default_namespace = $hconf->{default_namespace};
    # pre-cache relevant source to mask the whole process 
    # a transactional look
    # pre-cache all type info
    my %typedef = ();
    foreach my $f (@typedef) {
        #print STDERR $f, "\n";
        my @f = File::Spec::->splitdir($f);
        ( my $n = $f[-1] ) =~ s/\.typedef$//o;
        $n =~ s/\_\_/::/gio;
        $typedef{$n} = _load_yaml($f);
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
    # locate all known types from global typemap
    my $global_typemap = {};
    my $global_typemap_file = File::Spec::->catfile(
        $Config{privlib}, 'ExtUtils', 'typemap');
    _read_typemap($global_typemap_file, $global_typemap);
    # locate those types which should be ignored
    my $ignore_typemap = {};
    _read_typemap($typemap_dot_ignore, $ignore_typemap);
    # locate simple types
    my $simple_typemap = {};
    _read_typemap($typemap_dot_simple, $simple_typemap);
    
    foreach my $n (keys %type) {
        #print STDERR "name: ", $n, "\n";
        foreach my $t (@{$type{$n}}) {
            my $type = $t;
            # simply normalize
            $type =~ s/^\s+//gio;
            $type =~ s/\s+$//gio;
            $type =~ s/\s+/ /gio;
            unless (exists $global_typemap->{$type} or 
                      exists $simple_typemap->{$type} or 
                        exists $ignore_typemap->{$type}) {
                # transform
                # template to a function call
                # '<' => '('
                $type =~ s/\</(/gio;
                # '>' => ')'
                $type =~ s/\>/)/gio;
                # transform rule for coutinous (two or more) 
                # pointer ('*') or reference ('&')
                # * (*|&) => PTR (PTR|REF)
                # which means second will ALWAYS be a parameter of 
                # the first
                # for instance:
                # '* & *' => 'PTR( REF( PTR ))'
                # FIRST GREDDY IS IMPORTANT
                while ($type =~ 
                         s{(.*(?<=(?:\*|\&))\s*)(\*|\&)}
                          {$1.'('. ($2 eq '*' ? ' PTR' : ' REF'. ')') }gei) {
                    1;
                }
                # leading or standalone pointer or reference
                # '*' => ', PTR'
                $type =~ s/\*/, PTR/gio;
                # '&' => ', REF'
                $type =~ s/\&/, REF/gio;
                #print STDERR "orig : ", $t, "\n";
                #print STDERR "patch: ", $type, "\n";
                # FIXME: const takes one additional parameter
                # mask bareword as a function call without any parameter
                $type =~ s/\b(\w+)\b(?!(?:\(|\:))/$1()/gio;
                $type = 'transform( '. $type .' )';
                print $type, "\n";
                eval $type;
            }
        }
    }
    
    exit 0;
}

&main;

sub AUTOLOAD {
    #print $AUTOLOAD, "\n";
}
