#! /usr/bin/perl -w

use warnings;
use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw/GetOptions/;

use YAML ();

=head1 DESCRIPTION

=cut

sub usage {
    print << "EOU";
usage     : $0 <conditions> <fields> file.yaml
conditions: -c field1=value1 ...
fields    : -f field1 -f field2 ...
EOU
    exit 1;
}

sub main {
    my $condition = {};
    my $fields    = [];
    my $h         = '';
    GetOptions(
        'c|condition=s' => $condition,
        'f|field:s'     => $fields, 
        'h|help'        => \$h, 
    );
    usage() if $h;
    usage() unless @ARGV;
    my $yaml_file = $ARGV[0];
    croak("file not found: $yaml_file") unless 
      -f $yaml_file;
    local ( *YAML, );
    open YAML, '<', $yaml_file or 
      croak("cannot open file to read: $!");
    my $cont = do { local $/; <YAML> };
    my $inputs  = YAML::Load($cont);
    my $outputs = [];
    HASH_LOOP:
    foreach my $hash (@$inputs) {
        COND_LOOP:
        foreach my $k (keys %$condition) {
            if (exists $hash->{$k}) {
                if ($condition->{$k} =~ m{^m?/(.+)/}io) {
                    my $v = $1;
                    next HASH_LOOP unless $hash->{$k} =~ m/$v/;
                }
                else {
                    my $v = $condition->{$k};
                    next HASH_LOOP unless $hash->{$k} eq $v;
                }
            }
            else {
                next HASH_LOOP;
            }
        }
        if (@$fields) {
            my $hash2 = {};
            foreach my $f (@$fields) {
                if (exists $hash->{$f}) {
                    $hash2->{$f} = $hash->{$f};
                }
            }
            push @$outputs, $hash2;
        }
        else {
            push @$outputs, $hash;
        }
    }
    print YAML::Dump($outputs), "\n";
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
