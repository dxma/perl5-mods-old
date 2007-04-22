#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use File::Spec ();

=head1 DESCIPTION

Create xscode.mk

B<NOTE>: Invoked after group of formatted qtedi productions completed.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <out_group_dir> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage if @ARGV < 1;
    
    my ( $out_group_dir, $out, ) = @ARGV;
    die "directory $out_group_dir not found!" unless 
      -d $out_group_dir; 
    
    my $xscode_dot_mk = '';
    foreach my $m (glob(File::Spec::->catfile($out_group_dir, '*.meta'))) {
        my $meta = (File::Spec::->splitdir($m))[-1];
        ( my $classname = $meta ) =~ s/\.meta$//io;
        my @deps = glob(File::Spec::->catfile(
            $out_group_dir, "$classname.*"));
        $xscode_dot_mk .= "$classname.xs: ". join(" ", @deps). "\n\n";
        $xscode_dot_mk .= "$classname.pm: $m\n\n";
    }
    
    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die 
          "cannot open file to write: $!";
        print OUT $xscode_dot_mk;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $xscode_dot_mk;
    }
    exit 0;
}

&main;
