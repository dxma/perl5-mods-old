#! /usr/bin/perl -w
# Author: Dongxu Ma

use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw(GetOptions);
use File::Spec;

use YAML::Syck qw/Load Dump/;
use Template;

INIT {
    require Template::Stash;
    no warnings 'once';
    $Template::Stash::PRIVATE = undef;
}

=head1 DESCRIPTION

Create <module>.xs according to <module>.{meta, function.public,
signal, slot.public}

=cut

my %opt;

sub usage {
    print STDERR << "EOU";
usage: $0 <module.xs> [conf] [template] [packagemap] [output]
conf       : -conf module.conf
template   : -template template
packagemap : -packagemap 05typemap/packagemap
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
        'conf=s',
        'template=s',
        'packagemap=s@',
        'o|outoput=s',
        'h|help',
    ) or usage();
    usage() if $opt{h};
    usage() unless @ARGV;
    croak "module.conf not found" if !-f $opt{conf};
    croak "template dir not found" if !-d $opt{template};
    #croak "packagemap not found" if !-f $opt{packagemap};

    my %f = ();
    foreach my $p (@ARGV) {
        my $f = (split /\//, $p)[-1];
        my @f = split /\./, $f;
        shift @f;
        my $k = join(".", @f);
        $f{$k} = $p;
    }
    croak "<class>.meta not found: $f{meta}" if !-f $f{meta};
    #croak "<class>.enum not found: $f{enum}" if !-f $f{enum};
    #croak "<class>.function.public not found: $f{'function.public'}" if
    #  !-f $f{'function.public'};
    #croak "<class>.xs not found: $f{xs}" if !-f $f{xs};
    my $mod_conf   = load_yaml($opt{conf});
    my $packagemap = {};
    foreach my $f (@{$opt{packagemap}}) {
        my $map = load_yaml($f);
        foreach my $k (keys %$map) {
            $packagemap->{$k} = $map->{$k};
        }
    }
    my $meta  = load_yaml($f{meta});
    my $typemap = exists $f{typemap} ? load_yaml($f{typemap}) : {};
    my $ns    = $meta->{TYPE} eq 'namespace' ? 1 : 0;
    my $defns =
      $meta->{NAME} eq $mod_conf->{default_namespace} ? 1 : 0;
    my $enums = exists $f{enum} ? load_yaml($f{enum}) : [];
    # scan for sprintf, vsprintf
    my $funcs = exists $f{'function.public'} ?
      load_yaml($f{'function.public'}) : [];
    my @parent = ();
    my $dll_export_mark = exists $mod_conf->{dll_export_mark} ?
      $mod_conf->{dll_export_mark} : undef;
    if (exists $meta->{ISA}) {
        my @dir = File::Spec::->splitpath($f{meta});
        pop @dir;
        foreach my $e (@{$meta->{ISA}}) {
            # FIXME: template class parent
            # FIXME: typedef template class parent
            next if $e->{NAME} =~ /^std/io;
            next if $e->{NAME} =~ /\</io;
            if ($e->{RELATIONSHIP} eq 'public') {
                if (defined $dll_export_mark) {
                    # skip non-exported
                    ( my $file = $e->{NAME} ) =~ s/\:\:/__/go;
                    my $path = File::Spec::->catpath(@dir, $file. '.meta');
                    if (-f $path) {
                        my $isa = load_yaml($path);
                        push @parent, $e->{NAME} if exists $isa->{PROPERTY} and grep { $_ eq $dll_export_mark } @{ $isa->{PROPERTY} };
                    }
                }
                else {
                    push @parent, $e->{NAME};
                }
            }
        }
    }
    my @proto = ();
    if (!$ns) {
        local ( *F, );
        open F, $f{xs} or croak "cannot open file to read: $!";
        while (<F>) {
            if (/^##\s+/o) {
                chomp;
                s/^##//o;
                push @proto, $_;
            }
        }
    }
    my @printf = grep { /^(?:vs|s)printf$/o }
      map { $_->{NAME} } @$funcs;

    # generate xs file from template
    my $out = '';
    my $template = Template::->new({
        INCLUDE_PATH => $opt{template},
        INTERPOLATE  => 0,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 0,
        TRIM         => 1,
        EVAL_PERL    => 1,
        #STRICT       => 1,
    });
    my $var = {
        my_cclass    => $meta->{NAME},
        my_type      => $meta->{TYPE},
        my_module    => $ns ? $meta->{NAME} : $meta->{MODULE},
        my_package   => $ns ? $meta->{NAME} : $packagemap->{$meta->{NAME}},
        my_file      => $ns ? 'null' : $meta->{FILE},
        my_version   => $mod_conf->{current_version},
        my_author    => $mod_conf->{module_author},
        my_mail      => $mod_conf->{contact_mail},
        my_enums     => $enums,
        my_parents   => \@parent,
        my_methods   => \@proto,
        my_printfs   => \@printf,
        my_bootstrap => $defns,
        my_packagemap=> $packagemap,
        my_typemap   => $typemap,
    };
    $template->process('pmcode.tt2', $var, \$out) or
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
