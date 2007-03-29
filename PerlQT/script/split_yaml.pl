#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT :flock);
use YAML;
use File::Spec ();

=head1 DESCIPTION

Split formatted QTEDI production according to namespace.

For each namespace there will be 2 files generated:

  1. <namespace_name>.typemap
  2. <namespace_name>.function

B<NOTE>: 'namespace' here, as a generic form, stands for any
full-qualified class/struct/namespace name in C. 

B<NOTE>: filename length limit is _PC_NAME_MAX on POSIX,
normally this should not be an issue. 

B<NOTE>: a special namespace - std, will hold any entry which doesn't
belong to other namespace. 

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <formatted_qtedi_output.yaml> <output_directory>
EOU
    exit 1;
}

=over

=item write_to_file

A configurable hook to save content into a file. How/where to
create such file and the file name is totally blind for caller. 

B<NOTE>: Currently create the file with a full-qualified
namespace string as its name. 

=back

=cut

sub write_to_file {
    my ( $cont, $root_dir, @namespace ) = @_;
    
    my $NS_DELIMITER = q(::);
    my $FN_DELIMITER = q(__);
    my $FN_DEFAULT   = q(std);
    die "root directory not found" unless -d $root_dir;
    my $filename;
    if (@namespace) {
        $filename = join($NS_DELIMITER, @namespace);
        $filename =~ s/(?:\Q$NS_DELIMITER\E)+/$FN_DELIMITER/ge;
    }
    else {
        $filename = $FN_DEFAULT;
    }
    $filename = File::Spec::->catfile($root_dir, $filename);
    foreach my $k (keys %$cont) {
        local ( *OUT );
        sysopen OUT, $filename. '.'. lc($k), O_CREAT|O_WRONLY or 
          die "cannot open file to write: $!";
        until (flock OUT, LOCK_EX) { sleep 3; }
        seek OUT, 0, 2;
        my $cont_dump = Dump($cont->{$k});
        print OUT $cont_dump;
        close OUT or die "cannot write to file: $!";
    }
}

sub main {
    usage() unless @ARGV = 2;
    my ( $in, $out ) = @ARGV;
    die "file not found" unless -f $in;
    die "directory not found" unless -d $out;
    
    local ( *HEADER );
    open HEADER, '<', $in or die "cannot open file: $!";
    my $cont = do { local $/; <HEADER>; };
    close HEADER;
    my ( $entries ) = Load($cont);
    
    exit 0;
}

&main;
