#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use File::Spec ();
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create grouplist.mk

B<NOTE>: Internal use only.

B<NOTE>: Should ONLY be invoked inside group.mk

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <out_group_dir> [<grouplist.mk>]
EOU
    exit 1;
}

sub main {
    usage() if @ARGV < 1;
    my ( $out_group_dir, $group_dot_mk, $out ) = @ARGV;
    die "directory $out_group_dir not found" unless 
      -e $out_group_dir;
    die "file $group_dot_mk not found" unless 
      -f $group_dot_mk;
    local ( *DIR, );
    opendir DIR, $out_group_dir or die "cannot open dir: $!";
    my @f = map { File::Spec::->catfile($out_group_dir, $_) } 
      grep { not m/^\./io } 
        readdir DIR;
    closedir DIR;
    my $grouplist_dot_mk = 
      "GROUP_YAMLS := ". join(" ", @f). "\n\n";
    # lost of standard files produced by latest gen_group
    # forces re-run of gen_group 
    local ( *GROUP_DOT_MK, );
    open GROUP_DOT_MK, '<', $group_dot_mk or 
      die "cannot open file to read: $!";
    $grouplist_dot_mk .= "\$(GROUP_YAMLS): \$(GROUP_DOT_MK) ". 
      "\$(GROUPLIST_DOT_MK)\n";
    my $strip = <GROUP_DOT_MK>;
    my $l;
    while (defined ($l = <GROUP_DOT_MK>)) {
        last if $l =~ m/^$/io;
        $grouplist_dot_mk .= $l;
    }
    close GROUP_DOT_MK;
#     $grouplist_dot_mk .= "DELTA_GROUP_YAMLS = \$(filter-out ". 
#       "\$(addprefix \$(OUT_GROUP_DIR)/,". 
#         "\$(shell ls \$(OUT_GROUP_DIR))),\$(GROUP_YAMLS))\n";
#     $grouplist_dot_mk .= "ifneq (\$(DELTA_GROUP_YAMLS),)\n";
#     $grouplist_dot_mk .= "\$(info \$(DELTA_GROUP_YAMLS))\n";
#     $grouplist_dot_mk .= "\$(info some target file missing)\n";
#     $grouplist_dot_mk .= "\$(GROUPLIST_DOT_MK): \n";
#     $grouplist_dot_mk .= "endif\n\n";
#     $grouplist_dot_mk .= "ifeq (\$(DELTA_GROUP_YAMLS),)\n";
#     $grouplist_dot_mk .= "\$(info \$(DELTA_GROUP_YAMLS))\n";
#     $grouplist_dot_mk .= "\$(info all target files found)\n";
#     $grouplist_dot_mk .= "\$(GROUPLIST_DOT_MK): \$(GROUP_YAMLS)\n";
#     $grouplist_dot_mk .= "endif\n\n";
    
    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die 
          "cannot open file to write: $!";
        print OUT $grouplist_dot_mk;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $grouplist_dot_mk;
    }
    exit 0;
}

&main;
