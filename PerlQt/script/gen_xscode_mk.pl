#! /usr/bin/perl -w
# Author: Dongxu Ma

use strict;
#use English qw( -no_match_vars );
use Carp;
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use File::Spec;
use Getopt::Long qw/GetOptions/;

use YAML::Syck qw(Load);

=head1 DESCRIPTION

Create xscode.mk

B<NOTE>: Invoked after group of formatted qtedi productions completed.

=cut

my %opt;

sub usage {
    print STDERR << "EOU";
usage: $0 <in_xscode_dir> <out_xscode_dir> <out_typemap_dir> [<output_file>]
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
        'h|help',
    ) or usage();
    usage() if $opt{h};
    usage() if !@ARGV;
    
    my ( $in_xscode_dir, $out_xscode_dir, $out_pmcode_dir, 
         $out_typemap_dir, $out, ) = @ARGV;
    croak "directory $in_xscode_dir not found!" unless 
      -d $in_xscode_dir; 
    croak "module.conf not found: $opt{conf}" if !-f $opt{conf};
    
    my $mod_conf      = load_yaml($opt{conf});
    my $export_mark   = exists $mod_conf->{dll_export_mark} ?
      $mod_conf->{dll_export_mark} : undef;
    my $xscode_dot_mk = '';
    my @xs_files = ();
    my @pm_files = ();
    my ( $xs_file, $pm_file, );
    
    foreach my $m (glob(File::Spec::->catfile(
        $in_xscode_dir, '*.meta'))) {
        my $meta_file = (File::Spec::->splitdir($m))[-1];
        ( my $classname = $meta_file ) =~ s/\.meta$//io;
        # no need to include classname.function
        # which has member function implementations
        my @deps = 
          grep { not m/\.(?:function|protected|friend)$/io } 
            glob(File::Spec::->catfile(
                $in_xscode_dir, $classname. ".*"));
        push @deps, File::Spec::->catfile(
            $out_typemap_dir, $classname. ".typemap") if 
              -f File::Spec::->catfile($out_typemap_dir, 
                                       $classname. ".typemap");
        # skip those have neither .enum nor .public
        my %deps = map { (split /\./)[-1] => 1 } @deps;
        next unless exists $deps{enum} or exists $deps{public};
        
        # get module name from .meta
        my $meta = load_yaml($m);
	# skip masked
	next if grep { $_ eq $meta->{MODULE} } @{$mod_conf->{mask_modules}};
        # skip not exported
        if (defined $export_mark) {
            my $skip = 0;
            $skip = 1 if !exists $meta->{PROPERTY};
            $skip = 1 if !grep { $_ eq $export_mark }
              @{$meta->{PROPERTY}};
            $skip = 0 if $meta->{NAME} eq
              $mod_conf->{default_namespace};
            if ($skip) {
                print STDERR "skip non-exported: ", $meta->{NAME}, "\n";
                next;
            }
        }
        my $module = exists $meta->{MODULE} ? $meta->{MODULE} : '';
        my @module = split /\:\:/, $module;
        my @name   = split /\:\:/, $meta->{TYPE} eq 'namespace' ? 
          $meta->{NAME} : $meta->{PERL_NAME};
        $name[-1] .= '.pm';
        
        # deps for module.xs
        $xs_file = File::Spec::->catfile($out_xscode_dir, "$classname.xs");
        if ($meta->{TYPE} eq 'namespace') {
            $xs_file = '';
            goto MODULE_PM;
        }
        push @xs_files, $xs_file;
        # enum implemented by enum.pm in dot pm
        $xscode_dot_mk .= $xs_file. ": ". 
          join(" ", grep { not m/\.enum$/o } @deps). "\n";
        # rule for module.xs
        $xscode_dot_mk .= "\t\$(_Q)echo generating \$@\n";
        $xscode_dot_mk .= 
          "\t\$(_Q)[[ -d \$(dir \$@) ]] || \$(CMD_MKDIR) \$(dir \$@)\n";
        $xscode_dot_mk .= "\t\$(_Q)\$(CMD_CREAT_XS) ". 
          "-conf \$(MODULE_DOT_CONF) ".
            "-template \$(TEMPLATE_DIR) -typemap \$(TYPEMAP) ". 
              "-packagemap \$(PACKAGEMAP) -enummap \$(ENUMMAP) ". 
                "-default_typedef \$(DEFAULT_TYPEDEF) \$(addprefix -packagemap ,\$(wildcard \$(MAKE_ROOT)/packagemap.*)) -o \$@ \$^\n\n";

MODULE_PM:        
        # deps for module.pm
        $pm_file = File::Spec::->catfile($out_pmcode_dir, @module, @name);
        push @pm_files, $pm_file;
        # .function.public for operator (function) overload
        $xscode_dot_mk .= $pm_file. ": ". 
          join(" ", grep { m/\.(?:meta|public|enum|typemap)$/o } @deps). 
            " ". $xs_file. "\n";
        # rule for module.pm
        $xscode_dot_mk .= "\t\$(_Q)echo generating \$@\n";
        $xscode_dot_mk .= 
          "\t\$(_Q)[[ -d \$(dir \$@) ]] || \$(CMD_MKDIR) \$(dir \$@)\n";
        $xscode_dot_mk .= "\t\$(_Q)\$(CMD_CREAT_PM) ". 
          "-conf \$(MODULE_DOT_CONF) ". 
            "-template \$(TEMPLATE_DIR) -packagemap \$(PACKAGEMAP) ". 
                "\$(addprefix -packagemap ,\$(wildcard \$(MAKE_ROOT)/packagemap.*)) ".
                  "-o \$@ \$^\n\n";
    }
    
    # write XS_FILES and PM_FILES
    $xscode_dot_mk .= "XS_FILES := ". join(" ", @xs_files). "\n";
    $xscode_dot_mk .= "PM_FILES := ". join(" ", @pm_files). "\n";
    
    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die 
          "cannot open file to write: $!";
        print OUT $xscode_dot_mk;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $xscode_dot_mk;
    }
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
