#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create typemap accordingly to all relevant source: 

<module>.{function.public, function.protected, signal, slot.public,
slot.protected} and <module>.typedef

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <module>.function.public ... <module>.typedef
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV < 2;
    exit 0;
}

&main;
