#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use YAML ();
use File::Spec ();

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
usage: $0 <module.conf> <typemap.dep> <in_xscode_dir> [<out_typemap>]
EOU
    exit 1;
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

sub main {
    usage() if @ARGV < 3;
    my ( $module_dot_conf, $typemap_dot_dep, $in_xscode_dir, 
         $out ) = @ARGV;
    die "file $module_dot_conf not found" unless 
      -f $module_dot_conf;
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
#     foreach my $n (keys %type) {
#         print STDERR "name: ", $n, "\n";
#         print STDERR join("\n", @{$type{$n}}), "\n";
#     }
    # generate typemap
    my $known   = {};
    my $unknown = {};
    
    
    exit 0;
}

&main;
