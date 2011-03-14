#! /usr/bin/perl -w
# Author: Dongxu Ma

use strict;
use warnings;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw/GetOptions/;
use File::Spec;

use YAML::Syck qw/Load Dump/;
use Template;

=head1 DESCRIPTION

Create MANIFEST

=cut

my %opt;

sub usage {
    print STDERR << "EOU";
usage   : $0 [template] [output]
template: -template template
output  : -o <output_file>
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

sub find_files {
    my ( $root_dir, ) = @_;
    
    my @dir = ( $root_dir, );
    my @file= ();
    while (@dir) {
        my $dir = pop @dir;
        local ( *D, );
        opendir D, $dir or croak "cannot opendir to read: $!";
        my @e = map { File::Spec::->catfile($dir, $_) } 
          grep { !/^\./o } readdir D;
        closedir D;
        foreach my $e (@e) {
            if (-f $e) {
                push @file, $e;
            }
            elsif (-d _) {
                push @dir, $e;
            }
        }
    }
    return wantarray ? @file : \@file;
}

sub main {
    GetOptions(
        \%opt,
        'conf=s',
        'template=s',
        'o|output=s',
        'h|help',
    ) or usage();
    usage() if $opt{h};
    #usage() if !@ARGV;
    croak "module.conf not found" if !-f $opt{conf};
    croak "template dir not found: $opt{template}" if !-d $opt{template};
    
    my $mod_conf = load_yaml($opt{conf});
    my $top_xs   = (split /\:\:/, $mod_conf->{default_namespace})[-1];
    $top_xs .= '.xs';
    my $pm_files = find_files('lib');
    my $xs_files = find_files('xs');
    my $t_files  = find_files('t');
    
    my $out = '';
    my $template = Template::->new({
        INCLUDE_PATH => $opt{template},
        INTERPOLATE  => 0,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 0,
        TRIM         => 1,
        EVAL_PERL    => 1,
        STRICT       => 1,
    });
    my $var = {
        my_pm_files => $pm_files,
        my_xs_files => $xs_files,
        my_t_files  => $t_files,
        my_top_xs   => $top_xs,
    };
    $template->process('manifest.tt2', $var, \$out) or 
      croak $template->error. "\n";
    $out .= "\n";
    if (defined $opt{o}) {
        local ( *OUT, );
        open OUT, '>', $opt{o} or croak "cannot open file to write: $!";
        print OUT $out;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $out;
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
