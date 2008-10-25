#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create <module>.xs accordingly to <module>.{meta, function.public,
function.protected, signal, slot.public, slot.protected} 

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <module.xs> <module>.meta ...
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV;
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
