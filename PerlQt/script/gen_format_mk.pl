#! /usr/bin/perl -w
# Author: Dongxu Ma

use warnings;
use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCIPTION

Create format.mk

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <header.mk> <in_noinc_dir> <in_format_dir> <out_format_dir> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage if @ARGV < 4;
    
    my ( $in, $in_noinc_dir, $in_format_dir, $out_format_dir, 
         $out, ) = @ARGV;
    die "header.mk not found!" unless -f $in;
    
    local ( *IN, );
    open IN, "<", $in or die "cannot open $in: $!";
    my $cont = do { local $/; <IN> };
    close IN;
    $cont =~ s{^\Q$in_noinc_dir\E(.*?)\.(?:h|H):\s*$}
              {$out_format_dir$1.yml: $in_format_dir$1.yml
\t\$(_Q)echo generating \$@
\t\$(_Q)[[ -d \$(dir \$@) ]] || \$(CMD_MKDIR) \$(dir \$@)
\t\$(_Q)\$(CMD_FORMAT_YML) \$< \$@.tmp
\t\$(_Q)\$(CMD_MV) \$@.tmp \$@
$out_format_dir$1.yml: 
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
