#! /usr/bin/perl -w

use warnings;
use strict;
#use English qw( -no_match_vars );
use File::Spec ();
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create grouplist.mk

B<NOTE>: Internal use only.

B<NOTE>: Should ONLY be invoked inside group.mk

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
    # copy rule to make GROUPLIST_DOT_MK
    my $strip = <GROUP_DOT_MK>;
    my $l;
    while (defined ($l = <GROUP_DOT_MK>)) {
        last if $l =~ m/^$/io;
        $grouplist_dot_mk .= $l;
    }
    close GROUP_DOT_MK;
    # depends on definition of GROUP_YAMLS
    $grouplist_dot_mk .= "\nifneq (\$(filter gen_typemap ". 
      "gen_xscode all,\$(_GOALS)),)\n";
    $grouplist_dot_mk .= "\$(info including \$(TYPEMAPLIST_DOT_MK))\n";
    $grouplist_dot_mk .= "include \$(TYPEMAPLIST_DOT_MK)\n";
    $grouplist_dot_mk .= "endif\n";
    
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

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
