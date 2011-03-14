#! /usr/bin/perl -w
# Author: Dongxu Ma

use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw(GetOptions);
use File::Spec;

use YAML::Syck qw/Load Dump/;

=head1 DESCRIPTION

create 05typemap/enummap from 04group/*.enum

=cut

my %opt;

sub usage {
    print STDERR << "EOU";
usage: $0 -dir <out_group_dir> -conf <module.conf> -o <enummap>
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
    GetOptions(
        \%opt,
        'conf=s',
        'dir=s',
        'o=s',
        'h|help',
    );
    #usage() unless @ARGV >= 1;
    usage() if $opt{h};
    croak "directory not found: $opt{dir}" if !-d $opt{dir};
    croak "module.conf not found: $opt{conf}" if !-f $opt{conf};
    
    my $mod_conf = load_yaml($opt{conf});
    my $default_namespace = $mod_conf->{default_namespace};
    my %enum_map = ();
    my $c = 0;
    foreach my $f (glob("$opt{dir}/*.enum")) {
        my $name = (File::Spec::->splitdir($f))[-1];
        ( my $class = $name ) =~ s/\_\_/::/go;
        $class =~ s/\.enum$//o;
        my $enums = load_yaml($f);
        foreach my $e (@$enums) {
            my %vmap = ();
            my $n = exists $e->{NAME} ? $e->{NAME} : 'anonymous'. $c++;
            foreach my $v (@{$e->{VALUE}}) {
                # skip enum key alias
                next if @$v > 1 and exists $vmap{$v->[1]};
                if ($name eq $default_namespace. '.enum') {
                    push @{$enum_map{$n}}, $v->[0];
                }
                else {
                    push @{$enum_map{$class}->{$n}}, $v->[0];
                }
                $vmap{$v->[0]}++;
            }
        }
    }
    my $out;
    if ($opt{o}) {
        open $out, '>', $opt{o} or croak "cannot open file to write: $!";
    }
    else {
        $out = \*STDOUT;
    }
    print $out Dump(\%enum_map);
    if ($opt{o}) {
        close $out or croak "cannot save to file: $!";
    }
    
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
