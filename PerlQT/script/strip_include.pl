#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCIPTION

Strip include/error directives to make 'semi' preprocessor happy ;-)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <cpp_header_to_strip_macro.h> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV;
    my ( $in, $out ) = @ARGV;
    die "file not found" unless -f $in;
    
    local ( *HEADER );
    open HEADER, '<', $in or die "cannot open file: $!";
    my $cont = do { local $/; <HEADER>; };
    close HEADER;
    $cont =~ s{^\s*#\s*include\s.+$}{}igmo;
    $cont =~ s{^\s*#\s*error\s.+$}{}igmo;
    if (defined $out) {
        local ( *STRIPPED );
        sysopen STRIPPED, $out, O_CREAT|O_WRONLY|O_TRUNC or 
          die "cannot open file to write: $!";
        print STRIPPED $cont;
        close STRIPPED or die "cannot write to file: $!";
    }
    else {
        print STDOUT $cont;
    }
    exit 0;
}

&main;
