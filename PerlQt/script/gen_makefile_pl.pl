#! /usr/bin/perl -w
# Author: Dongxu Ma

use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw(GetOptions);

use YAML::Syck qw/Load Dump/;
use Template;

INIT {
    require Template::Stash;
    no warnings 'once';
    $Template::Stash::PRIVATE = undef;
}

=head1 DESCRIPTION

Create Makefile.PL used to compile XS code and package.

=cut

my %opt;

sub usage {
    print STDERR << "EOU";
usage: $0 <module.xs> [conf] [conf_mk] [template] [output]
conf     : -conf module.conf
conf_mk  : -mk config.mk
template : -template template
output   : -o <output_file>
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
        'conf=s',
        'mk=s',
        'template=s',
        'o|outoput=s',
        'h|help',
    ) or usage();
    usage() if $opt{h};
    #usage() unless @ARGV;
    croak "module.conf not found" if !-f $opt{conf};
    croak "config.mk not found" if !-f $opt{mk};
    croak "template dir not found" if !-d $opt{template};
    
    my $mod_conf = load_yaml($opt{conf});
    my $mod = uc($mod_conf->{root_filename});
    local ( *F, );
    open F, $opt{mk} or croak "cannot open file to read: $!";
    my ( $inc, $def, $ld, );
    while (<F>) {
        chomp;
        if (/^_HEADER_DIR\s*\:?=/o) {
            $inc = (split /=\s*/, $_, 2)[1];
        }
        elsif (/^\Q$mod\E_DEFINES\s*\:?=/o) {
            $def = (split /=\s*/, $_, 2)[1];
            $def = '' if $def eq '$(empty)$(empty)';
        }
        elsif (/^LDFLAGS\s*\:?=/o) {
            $ld  = (split /=\s*/, $_, 2)[1];
        }
    }
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
        my_name    => $mod_conf->{default_namespace},
        my_version => $mod_conf->{current_version},
        my_author  => $mod_conf->{module_author},
        my_mail    => $mod_conf->{contact_mail},
        my_ldflags => $ld,
        my_defines => $def,
        my_include => $inc,
    };
    $template->process('makefile.pl.tt2', $var, \$out) or 
      croak $template->error. "\n";
    $out .= "\n";
    if ($opt{o}) {
        open my $F, '>', $opt{o} or 
          croak "cannot open file to write: $!";
        print $F $out;
        close $F or croak "cannot save to file: $!";
    }
    else {
        print $out, "\n";
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
