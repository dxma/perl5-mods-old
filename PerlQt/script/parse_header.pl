#! /usr/bin/perl -w
# Author: Dongxu Ma

use warnings;
use strict;
#use English qw( -no_match_vars );

use Fcntl qw(O_CREAT O_WRONLY O_TRUNC);
use FindBin ();
use lib qq($FindBin::Bin/../../Parse-QTEDI/lib);
# uncomment to enable parsing debug
#BEGIN { $Parse::QTEDI::DEBUG = 1; }
use Parse::QTEDI qw($parser);

=head1 DESCIPTION

Parse specified CPP header file. Get all required information for
marshalling interface.

B<NOTE>: currently focus on typedef and class declaration mainly.

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <path_to_preprocessed_header> [<path_to_output_file>]
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV;
    
    my ( $in, $out ) = @ARGV;
    die "file not found: $!" unless -f $in;
    my $source;
    local ( *OUT );
    
    {
        local ( *IN );
        open IN, '<', $in or die "cannot open file: $!";
        local $/;
        $source = <IN>;
        close IN or warn "cannot close file: $!";
    }
    if (defined $out) {
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or 
          die "cannot open file: $!";
        select OUT;
    }
    else {
        *OUT = *STDOUT;
    }
    
    #print STDERR $source;
    my $rc = $parser->begin($source);
    
    #print STDERR "generated!\n" if defined $rc;
    close OUT or warn "cannot write to file: $!" unless 
      fileno(OUT) == fileno(STDOUT);
    unlink $out if not defined $rc and defined $out and -f $out;
	if (defined $rc) {
        exit 0;
    }
    else {
        exit 2;
    }
}

main(@ARGV);

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
