#! /usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

use warnings;
use strict;
#use English qw( -no_match_vars );
use Carp;
use File::Spec ();
use Config;
use Getopt::Long qw/GetOptions/;

use YAML::Syck qw/Load Dump/;

my %opt;

=head1 DESCRIPTION

Generate <top_namespace>.xs, including all generated xs files in xs
folder, and function pointer, array pointer typedef collected from
class.typdef.

=cut

sub usage {
    print << "EOU";
usage        : $0 [manifest] [mod_conf] [xscode_dot_mk] [output]
manifest     : -manifest <.typemap.dep>
mod_conf     : -conf <module.conf>
xscode_dot_mk: -mk <xscode.mk>
output       : -o <output_file>
EOU
    exit 1;
}

sub load_yaml {
    my $path = shift;
    local ( *YAML, );
    open YAML, "<", $path or croak "cannot open file to read: $!";
    my $cont = do { local $/; <YAML> };
    close YAML;
    return Load($cont);
}

sub main {
    GetOptions(
        \%opt,
        'manifest=s',
        'conf=s',
        'mk=s',
        'o|output=s',
        'h|help',
    );
    usage() if $opt{h};
    #usage() if !@ARGV;
    croak ".typemap.dep not found: $opt{manifest}" if !-f $opt{manifest};
    croak "module.conf not found: $opt{conf}" if !-f $opt{conf};
    croak "xscode.mk not found: $opt{mk}" if !-f $opt{mk};
    
    my $mod_conf= load_yaml($opt{conf});
    my %header  = ();
    my @typedef = ();
    my @xscode  = ();
    open my $F, $opt{manifest} or croak "cannot open file to read: $!";
    while (<$F>) {
        chomp;
        if (/\.meta$/o) {
            my $meta = load_yaml($_);
            $header{$meta->{FILE}}++ if exists $meta->{FILE};
        }
        elsif (/\.typedef$/o) {
            my $typedef = load_yaml($_);
            foreach my $k (keys %$typedef) {
                push @typedef, $typedef->{$k} if 
                  $k =~ /^T_(?:ARRAY|FPOINTER)_/o;
            }
        }
    }
    open $F, $opt{mk} or croak "cannot open file to read: $!";
    while (<$F>) {
        if (/^([^\s]+?\.xs)\:\s/o) {
            my $f = $1;
            $f =~ s/^99xscode/xs/o;
            push @xscode, $f;
        }
    }
    
    my $OUT;
    if ($opt{o}) {
        open $OUT, '>', $opt{o} or croak "cannot open file to write: $!";
    }
    else {
        $OUT = \*STDOUT;
    }
    print $OUT <<EOL;
// WARNING: ANY CHANGE TO THIS FILE WILL BE LOST!
// MADE BY: $0

EOL
    my %skip_include = map { $_ => 1 } 
      exists $mod_conf->{skip_includes} ?
        @{$mod_conf->{skip_includes}} : ();
    foreach my $f (sort keys %header) {
        next if exists $skip_include{$f};
        print $OUT "#include \"", $f, "\"\n";
    }
    print $OUT <<EOL;

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#undef do_open
#undef do_close

EOL
    for (my $i = 0; $i < @typedef; $i++) {
        print $OUT "typedef ", $typedef[$i], ";\n";
    }
    my $nsroot = $mod_conf->{root_namespace};
    print $OUT <<EOL;

MODULE = $nsroot		PACKAGE = $nsroot
PROTOTYPES: DISABLE

EOL
    for (my $i = 0; $i < @xscode; $i++) {
        print $OUT "INCLUDE:\t\t", $xscode[$i], "\n";
    }
    
    if ($opt{o}) {
        close($OUT) or croak "cannot save to file: $!";
    }
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
