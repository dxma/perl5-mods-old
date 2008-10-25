#! /usr/bin/perl -w

use warnings;
use strict;
use Carp;
use YAML ();
#use English qw( -no_match_vars );
use Getopt::Long qw/GetOptions/;

=head1 DESCRIPTION

Generate xs code for template classes.

=cut

sub usage {
    print << "EOU";
usage: $0 -d_class class_meta_dir -d_typemap typemap_dir typemap_template
EOU
    exit 1;
}

sub main {
    my $d_class   = '';
    my $d_typemap = '';
    my $h         = '';
    GetOptions(
        'd_class=s'   => \$d_class,
        'd_typemap=s' => \$d_typemap, 
        'h|help'      => \$h, 
    );
    usage() if $h;
    usage() unless @ARGV;
    croak("class meta dir not found: $d_class") unless -d $d_class;
    croak("class typemap dir not found: $d_typemap") unless 
      -d $d_typemap;
    my $f_ttypes = $ARGV[0];
    my $ttypes;
    {
        local *TTYPES;
        open TTYPES, '<', $f_ttypes or 
          croak("cannot open file to read: $!");
        my $cont = do { local $/; <TTYPES> };
        $ttypes = YAML::Load($cont);
    }
    
    foreach my $ttype (@$ttypes) {
        # FIXME
        if ($ttype->{name} eq 'QPair') {
            
        }
        
    }
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 - 2008 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
