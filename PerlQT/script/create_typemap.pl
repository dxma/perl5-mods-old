#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);

=head1 DESCRIPTION

Create typemap according to all relevant source: 

<module>.{function.public, function.protected, signal, slot.public,
slot.protected} and <module>.typedef

B<NOTE>: Connect each involved C++ type (either function parameter
type or function return type) to known typemap slot; Record unknown
ones into typemap.unknown

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <grouplist.mk> <in_xscode_dir> [<out_typemap>]
EOU
    exit 1;
}

sub main {
    usage() if @ARGV < 2;
    my ( $grouplist_dot_mk, $in_xscode_dir, $out ) = @ARGV;
    die "file $grouplist_dot_mk not found" unless 
      -f $grouplist_dot_mk;
    die "dir $in_xscode_dir not found" unless 
      -d $in_xscode_dir;
    
    local ( *GROUPLIST, *IN_XSCODE, );
    open GROUPLIST, "<", $grouplist_dot_mk or 
      die "cannot open file: $!";
    # @standard holds all must-have files produced by latest gen_group
    my @standard = ();
    while (<GROUPLIST>) {
        chomp;
        # filter-out .function .meta
        # which has nothing to do with typemap generation
        if (m/^\s*GROUP\_YAMLS\s*\:\=\s*(.*)$/o) {
            push @standard, 
              grep { not m/\.(?:function|meta)$/io }
                split /\s+/, $1;
            last;
        }
    }
    #print STDERR join("\n", @standard), "\n";
    opendir IN_XSCODE, $in_xscode_dir or die "cannot open dir: $!";
    # @present holds all current-existing files under IN_XSCODE_DIR
    # with .function .meta filtered-out too
    my @present = grep { not m/\.(?:function|meta)$/io }
      grep { not m/^\./io } 
        readdir IN_XSCODE;
    closedir IN_XSCODE;
    
    # generate typemap
    # FIXME: support custom-patched files in @present
    
    exit 0;
}

&main;
