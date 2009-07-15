#! /usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

use warnings;
use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCIPTION

Create parse.mk

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <header.mk> <in_noinc_dir> <in_parse_dir> <out_parse_dir> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage if @ARGV < 4;
    
    my ( $in, $in_noinc_dir, $in_parse_dir, $out_parse_dir, 
         $out, ) = @ARGV;
    die "header.mk not found!" unless -f $in;
    
    local ( *IN, );
    open IN, "<", $in or die "cannot open $in: $!";
    my $cont = do { local $/; <IN> };
    close IN;
    $cont =~ s{^\Q$in_noinc_dir\E(.*?)\.h:\s*$}
              {$out_parse_dir$1.yaml: $in_parse_dir$1.i
\t\$(_Q)echo generating \$@
\t\$(_Q)[[ -d \$(dir \$@) ]] || \$(CMD_MKDIR) \$(dir \$@)
\t\$(_Q)\$(CMD_PARSE_HD) \$< \$@.tmp
\t\$(_Q)\$(CMD_MV) \$@.tmp \$@
$out_parse_dir$1.yaml: 
}miogx;
    
    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die 
          "cannot open file to write: $!";
        print OUT $cont;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $cont;
    }
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
