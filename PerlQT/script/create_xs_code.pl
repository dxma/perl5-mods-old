#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create <module>.pm accordingly to <module>.{meta, function.public} 

B<NOTE>: <module>.function.public is used to retrieve all available
operators. 

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <module.pm> <module>.meta <module>.function.public
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV < 3;
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
