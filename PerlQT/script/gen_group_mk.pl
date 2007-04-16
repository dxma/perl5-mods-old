#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCIPTION

Create group.mk

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <header.mk> <in_noinc_dir> <in_group_dir> <out_group_dir> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage if @ARGV < 4;
    
    my ( $in, $in_noinc_dir, $in_group_dir, $out_group_dir, 
         $out, ) = @ARGV;
    die "header.mk not found!" unless -f $in;
    
    local ( *IN, );
    open IN, "<", $in or die "cannot open $in: $!";
    my @cont = <IN>;
    close IN;
    my $group_dot_mk = '';
    $group_dot_mk .= ".PHONY: _GROUP_DOT_MK\n";
    $group_dot_mk .= '_GROUP_DOT_MK: $(FORMAT_YAMLS)'. "\n";
    $group_dot_mk .= "\t\$(_Q)[[ -d \$(OUT_GROUP_DIR) ]] " .
      "|| \$(CMD_MKDIR) \$(OUT_GROUP_DIR)\n";
    
    foreach (@cont) {
        chomp;
        if (s/\Q$in_noinc_dir\E/$in_group_dir/ge) {
            s/\:\s*$//gio;
            $group_dot_mk .= 
              "\t\$(_Q)\$(CMD_GROUP_YML) $_ \$(OUT_GROUP_DIR)\n";
        }
    }
    
    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die 
          "cannot open file to write: $!";
        print OUT $group_dot_mk;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $group_dot_mk;
    }
    exit 0;
}

&main;
