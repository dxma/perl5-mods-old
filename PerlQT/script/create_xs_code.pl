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

use YAML::Syck qw/Load/;

=head1 DESCRIPTION

Create <module>.xs accordingly to 
04group/<module>.{meta, function.public, enum} and 
05typemap/<module>.typemap

.enum and .typemap are optional

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <module.pm> <module>.*
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
    usage() unless @ARGV < 3;
    
    my $pm_file = shift;
    my %f  = map { (split /\./)[-1] => $_ } @ARGV;
    
    # open source files
    my $meta    = load_yaml($f{meta});
    my $public  = load_yaml($f{public});
    my $enum    = exists $f{enum} ? load_yaml($f{enum}) : {};
    my $typemap = exists $f{typemap} ? load_yaml($f{typemap}) : {};
    
    
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2009 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
