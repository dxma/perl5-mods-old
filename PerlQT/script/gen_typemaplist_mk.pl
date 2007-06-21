#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use File::Spec ();
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create typemaplist.mk

B<NOTE>: Internal use only.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

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
      "\$(TYPEMAP_BASE) \$(TYPEMAP_TEMPLATE)\n\n";
    # lost of standard files produced by latest gen_typemap
    # force re-run gen_typemap
    $typemaplist_dot_mk .= "ifneq (\$(filter-out \$(filter ". 
      "\$(TYPEMAP_FILES),\$(addprefix \$(OUT_TYPEMAP_DIR)/,". 
        "\$(shell ls \$(OUT_TYPEMAP_DIR)))),\$(TYPEMAP_FILES)),)\n";
    $typemaplist_dot_mk .= "\$(TYPEMAPLIST_DOT_MK): FORCE\n";
    $typemaplist_dot_mk .= "endif\n\n";
    
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
