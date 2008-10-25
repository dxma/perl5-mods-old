#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use File::Spec ();
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create typemaplist.mk

B<NOTE>: Internal use only.

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <out_typemap_dir> [<typemaplist.mk>]
EOU
    exit 1;
}

sub main {
    usage() if @ARGV < 1;
    my ( $out_typemap_dir, $out ) = @ARGV;
    die "directory $out_typemap_dir not found: $!" unless 
      -e $out_typemap_dir;
    local ( *DIR, );
    opendir DIR, $out_typemap_dir or die "cannot open dir: $!";
    my @f = map { File::Spec::->catfile($out_typemap_dir, $_) } 
      grep { m/\.typemap$/o } 
        readdir DIR;
    closedir DIR;
    my $typemaplist_dot_mk = 
      "TYPEMAP_YAMLS := ". join(" ", @f). "\n\n";
    $typemaplist_dot_mk .= "TYPEMAP_FILES := \$(TYPEMAP_YAMLS) ". 
      "\$(TYPEMAP_LIST) \$(TYPEMAP_TEMPLATE)\n\n";
    # TODO: missing of any in TYPEMAP_FILES 
    # triggers rebuild of TYPEMAPLIST_DOT_MK
    # depends on definition of TYPEMAP_YAMLS
    $typemaplist_dot_mk .= "ifneq (\$(filter gen_xscode all, ". 
      "\$(_GOALS)),)\n";
    $typemaplist_dot_mk .= "\$(info including \$(XSCODE_DOT_MK))\n";
    $typemaplist_dot_mk .= "include \$(XSCODE_DOT_MK)\n";
    $typemaplist_dot_mk .= "endif\n";
    
    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die 
          "cannot open file to write: $!";
        print OUT $typemaplist_dot_mk;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $typemaplist_dot_mk;
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
