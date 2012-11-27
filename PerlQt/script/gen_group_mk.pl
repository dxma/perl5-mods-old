#! /usr/bin/perl -w
# Author: Dongxu Ma

use warnings;
use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use Carp;

use YAML::Syck qw(Load);

=head1 DESCIPTION

Create group.mk

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <header.mk> <in_noinc_dir> <in_group_dir> <out_group_dir> <module.conf> [<output_file>]
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
    usage if @ARGV < 5;

    my ( $in, $in_noinc_dir, $in_group_dir, $out_group_dir,
         $module_dot_conf, $out ) = @ARGV;
    die "header.mk not found!" unless -f $in;
    die "module.conf not found!" unless -f $module_dot_conf;

    local ( *IN, );
    open IN, "<", $in or die "cannot open $in: $!";
    my @cont = <IN>;
    close IN;
    my $group_dot_mk = '';
    # update of group.mk also triggers a complete rebuild
    $group_dot_mk .= "\$(GROUPLIST_DOT_MK): ".
      "\$(GROUP_DOT_MK) \$(FORMAT_YAMLS)". "\n";
    $group_dot_mk .= "\t\$(_Q)".
      "\$(call _remove_dir,\$(OUT_GROUP_DIR))\n";
    $group_dot_mk .= "\t\$(_Q)".
      "\$(CMD_MKDIR) \$(OUT_GROUP_DIR)\n";

    # get namespace, export mark from module.conf
    my $mod_conf = load_yaml($module_dot_conf);
    my $default_namespace = '-nsdefault "'. $mod_conf->{default_namespace}. '"';
    my $root_namespace = '-nsroot "'. $mod_conf->{root_namespace}. '"';

    foreach (@cont) {
        chomp;
        if (s/\Q$in_noinc_dir\E/$in_group_dir/ge) {
            s/\.h\s*\:\s*$/.yml/gio;
            $group_dot_mk .= "\t\$(_Q)echo processing $_\n";
            $group_dot_mk .= "\t\$(_Q)\$(CMD_GROUP_YML) ".
              $default_namespace. " ". $root_namespace. " ".
                " -file $_ -dir \$(OUT_GROUP_DIR) -name \$(patsubst %.yml,%.\$(HEADER_PREFIX),\$(patsubst \$(IN_GROUP_DIR)/%,%,$_))\n";
        }
    }
    # command to create grouplist.mk
    $group_dot_mk .= "\t\$(_Q)echo generating \$@\n";
    $group_dot_mk .= "\t\$(_Q)\$(CMD_GROUPLIST_MK) ".
      "\$(OUT_GROUP_DIR) \$(GROUP_DOT_MK) \$@\n";
    $group_dot_mk .= "\t\$(_Q)for i in `ls \$(OUT_GROUP_DIR)`; ".
      "do touch \$(OUT_GROUP_DIR)/\$\$i; done\n";
    $group_dot_mk .= "\n";
    $group_dot_mk .= "ifneq (\$(filter gen_mapfile ".
      "gen_xscode gen_pmcode build test all list_\%,\$(_GOALS)),)\n";
    $group_dot_mk .= "\$(info including \$(GROUPLIST_DOT_MK))\n";
    $group_dot_mk .= "include \$(GROUPLIST_DOT_MK)\n";
    $group_dot_mk .= "endif\n";

    if (defined $out) {
        local ( *OUT, );
        sysopen OUT, $out, O_CREAT|O_WRONLY|O_TRUNC or die
          "cannot open file to write: $!";
        print OUT $group_dot_mk;
        close OUT or die "cannot save to file: $!";
    }
    else {
        print STDOUT $group_dot_mk;
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
