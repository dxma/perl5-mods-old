#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );

use Fcntl qw(O_CREAT O_WRONLY);
use Parse::RecDescent;

=head1 DESCIPTION

Parse specified CPP header file. Get all required information for
marshalling interface.

B<NOTE>: currently focus on typedef and class declaration mainly.

=cut

# Global flags 
# unless undefined, report fatal errors
#$::RD_ERRORS = 1;
# unless undefined, also report non-fatal problems
#$::RD_WARN = 1;
# if defined, also suggestion remedies
$::RD_HINT = 1;
# if defined, also trace parsers' behaviour
#$::RD_TRACE = 1;
# if defined, generates "stubs" for undefined rules
#$::RD_AUTOSTUB = 1;
# if defined, appends specified action to productions
#$::RD_AUTOACTION = 1;

sub usage {
    print STDERR << "EOU";
usage: $0 <path_to_blah.h> [<path_to_result>]
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV;
    
    my ( $in, $out ) = @ARGV;
    die "file not found: $!" unless -f $in;
    my $source;
    local ( *OUT );
    
    my $grammar = do { local $/; <DATA> };
    my $parser = Parse::RecDescent::->new($grammar);
    
    {
        local ( *IN );
        open IN, '<', $in or die "cannot open file: $!";
        local $/;
        $source = <IN>;
        close IN or warn "cannot close file: $!";
    }
    if (defined $out) {
        die "file not found: $!" unless -f $out;
        sysopen OUT, $out, O_CREAT|O_WRONLY or 
          die "cannot open file: $!";
    }
    else {
        *OUT = *STDOUT;
    }
    
    #print STDERR $source;
    my $rc = $parser->begin($source);
    
    close OUT or warn "cannot write to file: $!" unless 
      fileno(OUT) == fileno(STDOUT);
    unlink $out if not defined $rc and defined $out and -f $out;
    exit 0;
}

main(@ARGV);

__DATA__
# CORE SPECS
begin: '#' { print @item[1], "\n" }
