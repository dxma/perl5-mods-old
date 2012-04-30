#! /usr/bin/perl -w
# Author: Dongxu Ma

use warnings;
use strict;
use Carp;
use YAML::Syck qw/Load Dump/;
use File::Spec ();
use Config;
#use English qw( -no_match_vars );
use Getopt::Long qw/GetOptions/;

my %opt;

=head1 DESCRIPTION

Generate typemap for xsubpp.

=cut

sub usage {
    print << "EOU";
usage      : $0 [input_dir] [package_map] [output]
manifest   : -manifest <.typemap.dep>
package_map: -packagemap <package_map_file>
output     : -o <output_file>
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
        'manifest=s@',
        'packagemap=s@',
        'conf=s',
        'o|output:s',
        'h|help',
    );
    usage() if $opt{h};
    #usage() if !@ARGV;
    $opt{manifest} = [] if !$opt{manifest};
    $opt{packagemap} = [] if !$opt{packagemap};
    foreach my $f (@{$opt{manifest}}) {
        croak ".typemap.dep not found: $f" if !-f $f;
    }
    foreach my $f (@{$opt{packagemap}}) {
        croak "package map not found: $f" if !-f $f;
    }
    croak "module.conf not found: $opt{conf}" if !-f $opt{conf};

    my $mod_conf   = load_yaml($opt{conf});
    my $packagemap = {};
    foreach my $f (@{$opt{packagemap}}) {
        my $p = load_yaml($f);
        foreach my $k (keys %$p) {
            $packagemap->{$k} = $p->{$k};
        }
    }
    my @class = ();
    my @name  = ();
    foreach my $f (@{$opt{manifest}}) {
        open my $F, $f or croak "cannot open file to read: $!";
        while (<$F>) {
            chomp;
            next if !/\.meta$/o;
            my $meta = load_yaml($_);
            if ($meta->{TYPE} =~ /^(?:class|struct)/o) {
                push @class, $meta->{NAME};
                push @name,  $meta->{PERL_NAME};
            } else {
                # namespace
                if ($meta->{NAME} eq $mod_conf->{root_namespace}) {
                    push @class, $meta->{NAME};
                    push @name,  $meta->{NAME};
                    # make package for root namespace
                    $packagemap->{$meta->{NAME}} = $meta->{MODULE};
                }
            }
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
# this typemap is only used by xsubpp
# to marshal THIS in xs code
EOL
    for (my $i = 0 ; $i < @class; $i++) {
        my $name = $name[$i];
        print $OUT sprintf("%-40s\t\tT_PTROBJ_%04d", $name. ' *', $i), "\n";
    }
    print $OUT <<EOL;

################################################################
INPUT
EOL
    for (my $i = 0; $i < @class; $i++) {
        my $type    = $class[$i];
        croak "no package found for type: $type" if !exists $packagemap->{$type};
        my $package = $packagemap->{$type};
        my $index   = sprintf("%04d", $i);
        print $OUT <<EOL;
T_PTROBJ_$index
    if (sv_derived_from(\$arg, \\"$package\\"))
        \$var = reinterpret_cast<\$type>(SvIV((SV*)SvRV(\$arg)));
    else
        Perl_croak(aTHX_ \\"\$var is not of type $package\\");

EOL
    }
    print $OUT <<EOL;

################################################################
OUTPUT
EOL
    for (my $i = 0; $i < @class; $i++) {
        my $type    = $class[$i];
        croak "no package found for type: $type" if
          !exists $packagemap->{$type};
        my $package = $packagemap->{$type};
        my $index   = sprintf("%04d", $i);
        print $OUT <<EOL;
T_PTROBJ_$index
    sv_setref_pv(\$arg, \\"$package\\", (void *)\$var);

EOL
    }
    if ($opt{o}) {
        close($OUT) or croak "cannot save to file: $!";
    }
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 - 2012 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
