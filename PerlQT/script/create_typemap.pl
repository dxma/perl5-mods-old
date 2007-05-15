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
    my ( $typemap_dot_dep, $in_xscode_dir, $out ) = @ARGV;
    die "file $typemap_dot_dep not found" unless 
      -f $grouplist_dot_mk;
    die "dir $in_xscode_dir not found" unless 
      -d $in_xscode_dir;
    
    local ( *TYPEMAP_DOT_DEP, );
    open TYPEMAP_DOT_DEP, "<", $typemap_dot_dep or 
      die "cannot open file: $!";
    my @functions = ();
    my @signals   = ();
    my @slots     = ();
    while (<TYPEMAP_DOT_DEP>) {
        chomp;
        if (m/\.function\.(?:public|protected)$/o) {
            push @functions, $_;
        }
        elsif (m/\.signal$/o) {
            push @signals, $_;
        }
        elsif (m/\.slot\.(?:public|protected)$/o) {
            push @slots, $_;
        }
    }
    close TYPEMAP_DOT_DEP;
    
    # generate typemap
    
    exit 0;
}

&main;
