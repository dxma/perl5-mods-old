#! /usr/bin/perl -w
# Author: Dongxu Ma

use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw(GetOptions);

use YAML::Syck qw/Load Dump/;

=head1 DESCRIPTION

Create 05typemap/packagemap according to 04group/<module>.meta

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <out_group_dir> 05typemap/packagemap
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
    my ( $out_group_dir, $packagemap_file ) = @ARGV;
    usage() unless -d $out_group_dir;
    
    my $packagemap = {};
    my @metas = glob("$out_group_dir/*.meta");
    foreach my $m (@metas) {
        my $meta = load_yaml($m);
        if ($meta->{TYPE} eq 'namespace') {
            # FIXME
            $packagemap->{$meta->{NAME}} = $meta->{MODULE};
        }
        else {
            $packagemap->{$meta->{NAME}} = exists $meta->{PERL_NAME} ? 
              join('::', $meta->{MODULE}, $meta->{PERL_NAME}) : 
                $meta->{MODULE};
        }
    }
    
    local ( *PKGMAP, );
    open PKGMAP, ">", $packagemap_file or 
      croak("cannot open file to write: $!");
    print PKGMAP Dump($packagemap);
    close PKGMAP or croak("cannot save to file: $!");
    
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2009 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
