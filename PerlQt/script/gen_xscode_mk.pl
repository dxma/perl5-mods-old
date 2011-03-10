#! /usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use File::Spec ();
use YAML::Syck qw(Load);

=head1 DESCRIPTION

Create xscode.mk

B<NOTE>: Invoked after group of formatted qtedi productions completed.

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <in_xscode_dir> <out_xscode_dir> <out_typemap_dir> [<output_file>]
EOU
    exit 1;
}

sub main {
    usage if @ARGV < 2;
    
    my ( $in_xscode_dir, $out_xscode_dir, $out_typemap_dir, 
         $out, ) = @ARGV;
    die "directory $in_xscode_dir not found!" unless 
      -d $in_xscode_dir; 
    
    my $xscode_dot_mk = '';
    my $excl_std_dot_meta = File::Spec::->catfile(
        $in_xscode_dir, 'std.meta');
    my @xs_files = ();
    my @pm_files = ();
    my ( $xs_file, $pm_file, );
    
    foreach my $m (glob(File::Spec::->catfile(
        $in_xscode_dir, '*.meta'))) {
        my $meta = (File::Spec::->splitdir($m))[-1];
        ( my $classname = $meta ) =~ s/\.meta$//io;
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
        # skip namespace std
        next if $m eq $excl_std_dot_meta;
        # skip those have neither .enum nor .public
        my %deps = map { (split /\./)[-1] => 1 } @deps;
        next unless exists $deps{enum} or exists $deps{public};
        
        # get module name from .meta
        local ( *META );
        open META, "<", $m or die "cannot open file $m: $!";
        my $hcont = do { local $/; <META> };
        close META;
        my $entry = Load($hcont);
        my $module = exists $entry->{MODULE} ? $entry->{MODULE} : '';
        my @module = split /\:\:/, $module;
        
        # deps for module.xs
        $xs_file = File::Spec::->catfile(
            $out_xscode_dir, @module, "$classname.xs");
        push @xs_files, $xs_file;
        # enum implemented by enum.pm in dot pm
        # FIXME: TYPEMAP not added as dependency
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
                "-default_typedef \$(DEFAULT_TYPEDEF) -o \$@ \$^\n\n";
        
        # deps for module.pm
        $pm_file = File::Spec::->catfile(
            $out_xscode_dir, "pm", @module, 
            split /\_\_/, "$classname.pm");
        push @pm_files, $pm_file;
        # .function.public for operator (function) overload
        $xscode_dot_mk .= $pm_file. ": ". 
          join(" ", grep { m/\.(?:meta|public|enum)$/o } @deps). "\n";
        # rule for module.pm
        $xscode_dot_mk .= "\t\$(_Q)echo generating \$@\n";
        $xscode_dot_mk .= 
          "\t\$(_Q)[[ -d \$(dir \$@) ]] || \$(CMD_MKDIR) \$(dir \$@)\n";
        $xscode_dot_mk .= "\t\$(_Q)\$(CMD_CREAT_PM) ". 
          "-template \$(TEMPLATE_DIR) -packagemap \$(PACKAGEMAP) ". 
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
