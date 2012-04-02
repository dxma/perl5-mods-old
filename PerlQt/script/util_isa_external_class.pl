#!/usr/bin/perl
# $Header$
# $Author$

use warnings;
use strict;

#use English qw( -no_match_vars );
use Getopt::Long qw/GetOptions/;
use Carp;

use YAML::Syck qw/Load Dump/;

=head1 DESCRIPTION

List any class whose parent is an external class declared in typemap.manual

=cut

my %opt;

sub usage {
    print STDERR << "EOU";
usage: $0
EOU
    exit 0;
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
    Getopt::Long::Configure('no_ignore_case');
    GetOptions(
        \%opt,
        'h|help',
    ) or usage();
    usage() if $opt{h};
    #usage() unless @ARGV;

    my $packagemap = {};
    foreach my $f ("05typemap/packagemap", glob("packagemap.*")) {
        my $map = load_yaml($f);
        foreach my $k (keys %$map) {
            $packagemap->{$k} = $map->{$k};
        }
    }
    foreach my $f (glob("04group/*.meta")) {
        my $meta = load_yaml($f);
        next if !exists $meta->{ISA};
        ( my $f2 = $f ) =~ s/\.meta$/.typemap/o;
        $f2 =~ s/^04group/05typemap/o;
        my $typedef = -f $f2 ? load_yaml($f2) : {};
        foreach my $isa (@{$meta->{ISA}}) {
            next if $isa->{RELATIONSHIP} ne 'public';
            my $parent = $isa->{NAME};
            $parent = $typedef->{$parent} if exists $typedef->{$parent};
            # ( my $f3 = $parent ) =~ s/::/__/go;
            # $f3 = "04group/$f3.meta";
            # print "$meta->{NAME}: $parent\n" if !-f $f3;
            print "$meta->{NAME}: $parent\n" if !exists $packagemap->{$parent};
        }
    }
    exit 0;
}

&main;

=head1 AUTHOR

Dongxu Ma E<lt>dongxu.ma@gmail.comE<gt>

=cut

