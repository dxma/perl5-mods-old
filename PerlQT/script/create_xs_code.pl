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
usage: $0 <module.xs> <module>.*
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
    my $template_dir = '';
    GetOptions(
        't=s' => \$template_dir, 
    );
    usage() unless @ARGV >= 2;
    
    my $xs_file = shift @ARGV;
    my %f  = map { (split /\./)[-1] => $_ } @ARGV;
    
    # open source files
    # class name, mod name, class hierarchy
    croak "no meta file found for $xs_file" unless $f{meta};
    my $meta    = load_yaml($f{meta});
    # publish methods
    carp "no public file found for $xs_file" unless $f{public};
    my $publics = exists $f{public} ? load_yaml($f{public}) : [];
    # typedef info
    my $typemap = exists $f{typemap} ? load_yaml($f{typemap}) : {};
    my $subst_with_fullname = sub {
        my ( $type, ) = @_;
        
        return $type unless keys %$typemap;
        foreach my $t (keys %$typemap) {
            $type =~ s/(?<!\:)\b\Q$t\E/$typemap->{$t}/e;
        }
        #print STDERR $_[0], " => ", $type, "\n" if $_[0] ne $type;
        return $type;
    };
    
    # loop into each public method, group by name
    my $public_by_name = {};
    foreach my $i (@$publics) {
        # convert relevant field key to lowcase
        # no conflict with template commands
        my $name         = delete $i->{NAME};
        $i->{parameters} = delete $i->{PARAMETER};
        $i->{return}     = delete $i->{RETURN} if exists $i->{RETURN};
        # substitude with full typename for entries in typemap
        $i->{return} = $subst_with_fullname->($i->{return}) 
          if exists $i->{return};
        foreach my $p (@{$i->{parameters}}) {
            $p->{name} = delete $p->{NAME} if exists $p->{NAME};
            $p->{type} = delete $p->{TYPE};
            $p->{type} = $subst_with_fullname->($p->{type});
        }
        push @{$public_by_name->{$name}}, $i;
    }
    
    # generate xs file from template
    my $template = Template::->new({
        INCLUDE_PATH => $template_dir, 
        INTERPOLATE  => 0, 
        PRE_CHOMP    => 1, 
        PRE_PROCESS  => 'header.tt2', 
        EVAL_PERL    => 1, 
    });
    my $out = '';
    my $var = {
        my_name    => $meta->{NAME}, 
        my_module  => $meta->{PERL_NAME}, 
        my_package => $meta->{MODULE}, 
        my_method  => $public_by_name, 
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
