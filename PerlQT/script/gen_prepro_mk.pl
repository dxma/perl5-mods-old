#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCIPTION

Create prepro.mk

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <header.mk> <in_noinc_dir> <in_prepro_dir> <out_prepro_dir> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage if @ARGV < 4;
    
    my ( $in, $in_noinc_dir, $in_prepro_dir, $out_prepro_dir, 
         $out, ) = @ARGV;
    die "header.mk not found!" unless -f $in;
    
    local ( *IN, );
    open IN, "<", $in or die "cannot open $in: $!";
    my $cont = do { local $/; <IN> };
    $cont =~ s{^\Q$in_noinc_dir\E(.*?)\.h:\s*$}
              {$out_prepro_dir$1.i: $in_prepro_dir$1.h
\t\$(_Q)echo generating \$@
\t\$(_Q)[[ -d \$(dir \$@) ]] || \$(CMD_MKDIR) \$(dir \$@)
\t\$(_Q)\$(CMD_CAT) $in_noinc_dir/QtCore/qconfig.h \$< > \$@.h
\t\$(_Q)\$(CMD_PREPRO_HD) \$(OPT_CC_INPUT) \$@.h \$(OPT_CC_OUTPUT) \$@
\t\$(_Q)\$(CMD_RM) \$@.h
$out_prepro_dir$1.i: 
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
