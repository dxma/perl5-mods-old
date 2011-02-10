#! /usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

use strict;
#use English qw( -no_match_vars );
use Carp;
use Getopt::Long qw(GetOptions);

use YAML::Syck qw/Load Dump/;
use Template;

=head1 DESCRIPTION

Create <module>.xs accordingly to 
04group/<module>.{meta, function.public, enum} and 
05typemap/<module>.typemap

.enum and .typemap are optional

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 -template <template_dir> -typemap <typemap> -packagemap <packagemap> <module>.* <module.xs>
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
    my $template_dir    = '';
    my $typemap_file    = '';
    my $packagemap_file = '';
    my $xs_file         = '';
    GetOptions(
        'template=s'   => \$template_dir, 
        'typemap=s'    => \$typemap_file, 
        'packagemap=s' => \$packagemap_file, 
        'o|outoput=s'  => \$xs_file, 
    );
    usage() unless @ARGV >= 1;
    
    my %f  = map { (split /\./)[-1] => $_ } @ARGV;
    
    # open source files
    # class name, mod name, class hierarchy
    croak "no meta file found for $xs_file" unless $f{meta};
    my $meta    = load_yaml($f{meta});
    # publish methods
    carp "no public file found for $xs_file" unless $f{public};
    my $publics = exists $f{public} ? load_yaml($f{public}) : [];
    # typedef info
    my $typedef = exists $f{typemap} ? load_yaml($f{typemap}) : {};
    # global typemap
    my $typemap = load_yaml($typemap_file);
    # global packagemap
    my $packagemap = load_yaml($packagemap_file);
    my $subst_with_fullname = sub {
        my ( $type, ) = @_;
        
        return $type unless keys %$typedef;
        foreach my $t (keys %$typedef) {
            $type =~ s/(?<!\:)\b\Q$t\E/$typedef->{$t}/e;
        }
        #print STDERR $_[0], " => ", $type, "\n" if $_[0] ne $type;
        return $type;
    };
    
    # loop into each public method, group by name
    my $pub_method_by_name = {};
    foreach my $i (@$publics) {
        # convert relevant field key to lowcase
        # no conflict with template commands
        my $name         = delete $i->{NAME};
        $i->{parameters} = exists $i->{PARAMETER} ? 
          delete $i->{PARAMETER} : [];
        $i->{return}     = delete $i->{RETURN} if exists $i->{RETURN};
        # substitude with full typename for entries in typemap
        $i->{return} = $subst_with_fullname->($i->{return}) 
          if exists $i->{return};
        for (my $j = 0; $j < @{$i->{parameters}}; $j++) {
            my $p = $i->{parameters}->[$j];
            $p->{name} = exists $p->{NAME} ? delete $p->{NAME} : "arg$j";
            $p->{type} = delete $p->{TYPE};
            $p->{type} = $subst_with_fullname->($p->{type});
        }
        push @{$pub_method_by_name->{$name}}, $i;
    }
    
    # generate xs file from template
    my $template = Template::->new({
        INCLUDE_PATH => $template_dir, 
        INTERPOLATE  => 0, 
        PRE_CHOMP    => 1, 
        POST_CHOMP   => 0, 
        TRIM         => 1,
        EVAL_PERL    => 1, 
    });
    my $out = '';
    my $var = {
        my_cclass     => $meta->{NAME}, 
        my_type       => $meta->{type}, 
        my_module     => $meta->{MODULE}, 
        my_package    => $packagemap->{$meta->{NAME}}, 
        my_method     => $pub_method_by_name, 
        my_typemap    => $typemap, 
        my_packagemap => $packagemap, 
    };
    $template->process('body.tt2', $var, \$out) or 
      croak $template->error. "\n";
    print STDERR $out, "\n";
    
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2009 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
