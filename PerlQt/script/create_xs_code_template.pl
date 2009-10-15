#! /usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

use warnings;
use strict;
use Carp;
use YAML       ();
use File::Spec ();
use Config;
use Template   ();
#use English qw( -no_match_vars );
use Getopt::Long qw/GetOptions/;

my $MODULE_NAME  = 'Template';
my @SIMPLE_TYPES = (qw(T_BOOL T_CHAR T_ENUM T_ARRAY T_CALLBACK 
                       T_INT T_DOUBLE T_SHORT T_LONG T_FLOAT 
                       T_U_INT T_U_SHORT T_U_LONG T_U_CHAR 
                       T_IUV T_IV T_UV T_NV T_SV T_PV 
                       T_PTR));

=head1 DESCRIPTION

Generate xs code for template classes.

=cut

sub usage {
    print << "EOU";
usage    : $0 [group_dir] [typemap] [output] typemap_template
group_dir: -dgroup <group_dir>
typemap  : -typemap <path_to_typemap.tt2>
output   : -o <output_file>
EOU
    exit 1;
}

sub get_package {
    my ( $type_entry, $d_group, ) = @_;
    
    my $simple_type = join("|", @SIMPLE_TYPES);
    my $load_module_info_from_meta = sub {
        my ( $type, $d_group, ) = @_;
        
        ( my $f_type = $type ) =~ s/::/__/go;
        open FTYPE, '<', File::Spec::->catfile(
            $d_group, $f_type. '.meta') or 
              croak("cannot open file to read: $!");
        my $cont = do { local $/; <FTYPE> };
        close FTYPE;
        my $meta = YAML::Load($cont);
        return $meta->{MODULE};
    };
    
    my $ptype = $type_entry->{ptype};
    my $type  = $type_entry->{type};
    my $rc = 0;
    if ($ptype =~ m/^T_(?:CLASS|STRUCT)$/o) {
        $type =~ s/^const //o;
        $type_entry->{package} = 
          $load_module_info_from_meta->($type, $d_group);
        $type_entry->{is_object}  = 1;
        $type_entry->{is_pointer} = 0;
        $rc = 1;
    }
    elsif ($ptype =~ m/^T_(?:CLASS|STRUCT)_PTR$/o) {
        $type =~ s/^const //o;
        $type =~ s/ \*$//o;
        $type_entry->{package} = 
          $load_module_info_from_meta->($type, $d_group);
        $type_entry->{is_object}  = 1;
        $type_entry->{is_pointer} = 1;
        $rc = 1;
    }
    elsif ($ptype =~ m/^T_(?:$simple_type)(?:_PTR)?$/o) {
        $type_entry->{is_object}  = 0;
        $type_entry->{is_pointer} = $ptype =~ m/_PTR$/o ? 1 : 0;
        $rc = 1;
    }
    return $rc;
}

sub main {
    my $d_group   = '';
    my $f_typemap = '';
    my $f_out     = '';
    my $h         = '';
    GetOptions(
        'dgroup=s'  => \$d_group,
        'typemap=s' => \$f_typemap, 
        'o:s'       => \$f_out, 
        'h|help'    => \$h, 
    );
    usage() if $h;
    usage() unless @ARGV;
    croak("class meta dir not found: $d_group") unless -d $d_group;
    croak("typemap file not found: $f_typemap") unless -f $f_typemap;
    my $f_ttypes = $ARGV[0];
    my $ttypes;
    {
        local *TTYPES;
        open TTYPES, '<', $f_ttypes or 
          croak("cannot open file to read: $!");
        my $cont = do { local $/; <TTYPES> };
        $ttypes = YAML::Load($cont);
    }
    
    my $tt_config = {
        INCLUDE_PATH => File::Spec::->catpath(
            (File::Spec::->splitpath($f_typemap))[0, 1]), 
        INTERPOLATE  => 0, 
        EVAL_PERL    => 1, 
        PRE_CHOMP    => 0, 
        POST_CHOMP   => 1, 
    };
    #print STDERR 'INCLUDE_PATH = ', $tt_config->{INCLUDE_PATH}, "\n";
    my $tt  = Template::->new($tt_config);
    my $var = { Config => \%Config, };
    
    foreach my $ttype (@$ttypes) {
        if ($ttype->{name} eq 'QPair') {
            my $t1 = {};
            my $t2 = {};
            $t1->{type}  = $ttype->{first_type};
            $t1->{ptype} = $ttype->{first_ptype};
            $t2->{type}  = $ttype->{second_type};
            $t2->{ptype} = $ttype->{second_ptype};
            get_package($t1, $d_group);
            get_package($t2, $d_group);
            my $tt_out = '';
            $tt->process(
                'QPair.tt2', 
                { %$var, 
                  t1         => $t1, 
                  t2         => $t2, 
                  my_module  => $MODULE_NAME, 
                  # FIXME: package name
                  my_package => join("::", $MODULE_NAME, $ttype->{name}), 
              }, 
                \$tt_out, 
            ) or croak("cannot process QPair: ". $tt->error());
            print STDERR $tt_out, "\n";
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
