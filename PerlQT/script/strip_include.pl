#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );

=head1 DESCIPTION

Strip include directives to make 'semi' preprocessor happy ;-)

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <cpp_header_to_strip_macro.h>
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV;
    my ( $in, $out ) = @ARGV;
    die "file not found" unless -f $in;
    
    local ( *HEADER );
    open HEADER, '<', $in or die "cannot open file: $!";
    my $cont;
    {
        local $/;
        $cont = <HEADER>;
    }
    $cont =~ s{^\s*#\s*include\s.+$}{}igmo;
    if (defined $out) {
        local ( *STRIPPED );
        open STRIPPED, '>', $out or 
          die "cannot open file to write: $!";
        print STRIPPED $cont;
        close STRIPPED or die "cannot write to file: $!";
    }
    else {
        print STDOUT $cont;
    }
    exit 0;
}

main(@ARGV);
