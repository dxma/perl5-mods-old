#! /usr/bin/perl -w
# Author: Dongxu Ma

use warnings;
use strict;
use Carp;
#use English qw( -no_match_vars );
use Getopt::Long qw/GetOptions/;

use YAML::Syck qw/Load Dump/;
use Template;

=head1 DESCRIPTION

Generate xs code for template classes.

=cut

my %opt;

sub usage {
    print << "EOU";
usage    : $0 [template] [meta] [output] 05typemap/typemap_template
output   : -o 06template
meta     : -meta module.conf
template : -template template
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
        'meta=s',
        'template=s',
        'o|output=s',
        'h|help',
    ) or usage();
    usage() if $opt{h};
    usage() unless @ARGV;

    my $module_conf      = load_yaml($opt{meta});
    my $typemap_template = load_yaml($ARGV[0]);
    my $template_dir     = $opt{template};
    my $output_dir       = $opt{o};
    croak "no such directory: $template_dir" if !-d $template_dir;
    croak "no such directory: $output_dir" if !-d $output_dir;

    my $template = Template::->new({
        INCLUDE_PATH => $template_dir,
        OUTPUT_PATH  => $output_dir,
        INTERPOLATE  => 0,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 0,
        TRIM         => 1,
        EVAL_PERL    => 1,
        #STRICT       => 1,
    });
    my $count = 0;
    my ( $filename, $meta, $F, );
    my %packagemap = ();
    foreach my $tclass (@$typemap_template) {
        # skip QFlags
        next if $tclass->{name} eq 'QFlags';
        # skip not supported
        next if !-f "$template_dir/custom/$tclass->{name}.tt2";

        $filename = sprintf("T%03d", $count++);
        $meta = {
            FILE      => 'typemap_template',
            MODULE    => $module_conf->{default_namespace}. '::Template',
            NAME      => $tclass->{ctype},
            PERL_NAME => $filename,
            TYPE      => 'class',
        };
        $meta->{PROPERTY} = [ $module_conf->{dll_export_mark}, ] if exists $module_conf->{dll_export_mark};
        open $F, '>', "$output_dir/$filename.meta" or croak "cannot open file to write: $!";
        print $F Dump($meta);
        close $F or croak "cannot save to file: $!";
        $packagemap{$meta->{NAME}} = $meta->{MODULE}. '::'. $meta->{PERL_NAME};
        $template->process("custom/$tclass->{name}.tt2", $tclass, "$filename.function.public") or croak $template->error;
    }
    open $F, '>', "$output_dir/packagemap" or croak "cannot open file to write: $!";
    print $F Dump(\%packagemap);
    close $F or croak "cannot save to file: $!";
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 - 2012 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
