#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use YAML ();
use File::Spec ();
use Config;
use Parse::RecDescent ();
# make sure typemap exists
use ExtUtils::MakeMaker ();

=head1 DESCRIPTION

Create typemap according to all relevant source: 

<module>.{function.public, function.protected, signal, slot.public,
slot.protected} and <module>.typedef

B<NOTE>: Connect each involved C++ type (either function parameter
type or function return type) to known typemap slot; Record unknown
ones into typemap.unknown

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <module.conf> <typemap.ignore> <typemap.simple>
    <typemap.manual> <typemap.dep> <in_xscode_dir> [<out_typemap>]
EOU
    exit 1;
}

# for AUTOLOAD
# FIXME: ref of ptr, ptr of ref, ptr of ptr
sub PTR { 0 }
sub REF { 1 }
sub const {
    my $entry = shift;
    $entry->{const} = 1;
    return $entry;
}
sub unsigned {
    my $entry = shift;
    $entry->{unsigned} = 1;
    return $entry;
}
sub signed {
    my $entry = shift;
    $entry->{signed} = 1;
    return $entry;
}
sub void {
}
# mask CORE::int
*CORE::GLOBAL::int = sub {};

# QT template types
sub Q3PtrList {
}
sub Q3ValueList {
}
sub QFlags {
}
sub QList {
}
sub QMap {
}
sub QMultiMap {
}
sub QPair {
}
sub QVector {
}

=over

=item _transform

Final step to identify the structure information of a type. 

=back

=cut

sub _transform {
}

# internal use
our $AUTOLOAD;
our $TYPE;

our $NAMESPACE_DELIMITER = '__';
our $DEFAULT_NAMESPACE   = '';
our $CURRENT_NAMESPACE   = '';
# hash to hold all class's meta information
our %META_DICTIONARY = ();
# hash to hold all class's typedef information
our %TYPE_DICTIONARY = ();
our %SIMPLE_TYPEMAP  = ();
our %GLOBAL_TYPEMAP  = ();
our %IGNORE_TYPEMAP  = ();
our %MANUAL_TYPEMAP  = ();
# array to hold any unknown type(s)
our @TYPE_UNKNOWN    = ();

=over

=item _load_yaml

Internal use. Load a YAML-ish file and return its yaml-ed content.

=back

=cut

sub _load_yaml {
    my ( $f ) = @_;
    
    local ( *FILE, );
    open FILE, "<", $f or die "cannot open file: $!";
    my $cont = do { local $/; <FILE> };
    close FILE;
    my $hcont= YAML::Load($cont);
    return $hcont;
}

=over 

=item _read_typemap

Read supported type list inside a typemap file. Store each as a key of
hash passed-in. 

=back

=cut

sub _read_typemap {
    my ($typemap_file, $typemap, ) = @_;
    die "file $typemap_file not found" unless -f $typemap_file;
    local ( *TYPEMAP, );
    open TYPEMAP, "<", $typemap_file or die "cannot open file: $!";
    while (<TYPEMAP>) {
        chomp;
        last if m/^INPUT\s*$/o;
        next if m/^\#/io;
        next if m/^\s*$/io;
        next if m/^TYPEMAP\s*$/o;
        my @t = split /\s+/, $_;
        my $v = pop @t;
        my $k = join(" ", @t);
        $typemap->{$k} = $v;
    }
    close TYPEMAP;
}

sub main {
    usage() if @ARGV < 6;
    # FIXME: GetOpt::Long
    #        see script/gen_xscode_mk.pl
    my ( $module_dot_conf, 
         $typemap_dot_ignore, $typemap_dot_simple,
         $typemap_dot_manual, 
         $typemap_dot_dep, $in_xscode_dir, 
         $out ) = @ARGV;
    die "file $module_dot_conf not found" unless 
      -f $module_dot_conf;
    die "file $typemap_dot_ignore not found" unless 
      -f $typemap_dot_ignore;
    die "file $typemap_dot_simple not found" unless 
      -f $typemap_dot_simple;
    die "file $typemap_dot_manual not found" unless 
      -f $typemap_dot_manual;
    die "file $typemap_dot_dep not found" unless 
      -f $typemap_dot_dep;
    die "dir $in_xscode_dir not found" unless 
      -d $in_xscode_dir;
    
    # categorize input files
    my @meta    = ();
    my @typedef = ();
    my %member  = ();
    {
        local ( *TYPEMAP_DOT_DEP, );
        open TYPEMAP_DOT_DEP, "<", $typemap_dot_dep or 
          die "cannot open file: $!";
        while (<TYPEMAP_DOT_DEP>) {
            chomp;
            if (m/\.meta$/o) {
                push @meta, $_;
            }
            elsif (m/\.(function)\.(?:public|protected)$/o) {
                push @{$member{$1}}, $_;
            } 
            elsif (m/\.(signal)$/o) {
                push @{$member{$1}}, $_;
            } 
            elsif (m/\.(slot)\.(?:public|protected)$/o) {
                push @{$member{$1}}, $_;
            } 
            elsif (m/\.typedef$/o) {
                push @typedef, $_;
            }
        }
        close TYPEMAP_DOT_DEP;
    }
    # get default namespace from module.conf
    my $hconf = _load_yaml($module_dot_conf);
    our $DEFAULT_NAMESPACE;
    $DEFAULT_NAMESPACE = $hconf->{default_namespace};
    # pre-cache relevant source to mask the whole process 
    # a transactional look
    # pre-cache all meta info
    our %META_DICTIONARY;
    foreach my $f (@meta) {
        my @f = File::Spec::->splitdir($f);
        ( my $n = $f[-1] ) =~ s/\.meta$//o;
        $n =~ s/\_\_/::/gio;
        $META_DICTIONARY{$n} = _load_yaml($f);
    }
    # pre-cache all type info
    our %TYPE_DICTIONARY;
    foreach my $f (@typedef) {
        my @f = File::Spec::->splitdir($f);
        ( my $n = $f[-1] ) =~ s/\.typedef$//o;
        $n =~ s/\_\_/::/gio;
        $TYPE_DICTIONARY{$n} = _load_yaml($f);
    }
    # pre-cache all function info
    my %method = ();
    foreach my $t (qw/function signal slot/) {
        foreach my $f (@{$member{$t}}) {
            my @f = File::Spec::->splitdir($f);
            ( my $n = $f[-1] ) =~ 
              s/\.\Q$t\E(?:\.(?:public|protected))?$//;
            $n =~ s/\_\_/::/gio;
            $method{$t}->{$n} = _load_yaml($f);
        }
    }
    # collect types
    my %type = ();
    foreach my $t (keys %method) {
        foreach my $n (keys %{$method{$t}}) {
            #print STDERR "name: ", $n, "\n";
            my $existing_type = {};
            foreach my $m (@{$method{$t}->{$n}}) {
                # param
                if (exists $m->{PARAMETER}) {
                    foreach my $p (@{$m->{PARAMETER}}) {
                        #print STDERR "type: ", $p->{TYPE}, "\n";
                        unless (exists $existing_type->{$p->{TYPE}}) {
                            push @{$type{$n}}, $p->{TYPE};
                            $existing_type->{$p->{TYPE}} = 1;
                        }
                    }
                }
                # return type
                if (exists $m->{RETURN}) {
                    unless (exists $existing_type->{$m->{RETURN}}) {
                        push @{$type{$n}}, $m->{RETURN};
                        $existing_type->{$m->{RETURN}} = 1;
                    }
                }
            }
        }
    }
    # generate typemap
    # transform each type string into a function expression
    # each function contribute certain information
    # which will finally construct a self-deterministic type structure
    # missing functions are handled by AUTOLOAD
    my $known   = {};
    # in case failed lookup, push it into @TYPE_UNKNOWN
    our ( %SIMPLE_TYPEMAP, %GLOBAL_TYPEMAP, %IGNORE_TYPEMAP,
          %MANUAL_TYPEMAP, @TYPE_UNKNOWN, );
    # locate all known types from global typemap
    my $global_typemap_file = File::Spec::->catfile(
        $Config{privlib}, 'ExtUtils', 'typemap');
    _read_typemap($global_typemap_file, \%GLOBAL_TYPEMAP);
    # locate those types which should be ignored
    _read_typemap($typemap_dot_ignore, \%IGNORE_TYPEMAP);
    # locate simple types
    _read_typemap($typemap_dot_simple, \%SIMPLE_TYPEMAP);
    # locate manual types
    _read_typemap($typemap_dot_manual, \%MANUAL_TYPEMAP);
    
    # const takes one additional parameter
    # a tiny Parse::RecDescent grammar to work on
    # grabbing const parameter
    my $const_grammar = q{
    start : next_const const_body const_remainder 
            { $main::TYPE = $item[1]->[1]. "( ". $item[2]. " ) ". $item[3]; }
            { if ($item[2] eq '') { 
                  # something like 'QMenuBar * const'
                  $main::TYPE = $item[1]->[0].", ".$main::TYPE;
              } else {
                  $main::TYPE = $item[1]->[0]. $main::TYPE;
              }
            }
    const_remainder        : m/^(.*)\Z/o      { $return = $1; } 
                           | { $return = ''; }
    next_const             : m/^(.*?)\b(const)\b(?!\_)\s*(?!\()/o 
                             { $return = [$1, $2]; } 
    const_body_simple      : m/([^()*&]+)/io { $return = $1; }  
    next_const_body_token  : m/([^()]+)/io   { $return = $1; } 
    const_body     : const_body_simple ...!'(' { $return = $item[1]; }
                   | const_body_loop           { $return = $item[1]; } 
                   |                           { $return = '';       }
    const_body_loop: next_const_body_token 
                     ( '(' <commit> const_body_loop ')' 
                       { $return = $item[1]. $item[3]. $item[4]; } 
                     | { $return = '' } ) 
                     { $return = $item[1]. $item[2]; }
    };
    my $parser = Parse::RecDescent::->new($const_grammar)
      or die "Bad grammar!";
    our $CURRENT_NAMESPACE;
    foreach my $n (keys %type) {
        #print STDERR "name: ", $n, "\n";
        $CURRENT_NAMESPACE = $n;
        foreach my $t (@{$type{$n}}) {
            our $TYPE = $t;
            # simply normalize
            $TYPE =~ s/^\s+//gio;
            $TYPE =~ s/\s+$//gio;
            $TYPE =~ s/\s+/ /gio;
            unless (exists $GLOBAL_TYPEMAP{$TYPE} or 
                      exists $SIMPLE_TYPEMAP{$TYPE} or 
                        exists $MANUAL_TYPEMAP{$TYPE} or 
                          exists $IGNORE_TYPEMAP{$TYPE}) {
                # transform
                # template to a function call
                # '<' => '('
                $TYPE =~ s/\</(/gio;
                # '>' => ')'
                $TYPE =~ s/\>/)/gio;
                #print STDERR "orig : ", $t, "\n";
                # recursively process any bare 'const' word
                # skip processed and something like 'const_iterator'
                while ($TYPE =~ m/\bconst\b(?!\_)\s*(?!\()/o) {
                    defined $parser->start($TYPE) or die "Parse failed!";
                }
                #print STDERR "patch: ", $TYPE, "\n";
                # transform rule for coutinous (two or more) 
                # pointer ('*') or reference ('&')
                # * (*|&) => PTR (PTR|REF)
                # which means second will ALWAYS be a parameter of 
                # the first
                # for instance:
                # '* & *' => 'PTR( REF( PTR ))'
                # FIRST GREDDY IS IMPORTANT
                while ($TYPE =~ 
                         s{(.*(?<=(?:\*|\&))\s*)(\*|\&)}
                          {$1.'('. ($2 eq '*' ? ' PTR' : ' REF'. ')') }gei) {
                    1;
                }
                # leading or standalone pointer or reference
                # '*' => ', PTR'
                $TYPE =~ s/\*/, PTR/gio;
                # '&' => ', REF'
                $TYPE =~ s/\&/, REF/gio;
                # mask bareword as a function call without any
                # parameter
                # skip '(un)signed'
                $TYPE =~ s/\b(\w+)\b(?<!signed)(?!(?:\(|\:))/$1()/go;
                # '::' to $NAMESPACE_DELIMITER
                our $NAMESPACE_DELIMITER;
                $TYPE =~ s/\:\:/$NAMESPACE_DELIMITER/gio;
                #print $TYPE, "\n";
                $TYPE = '_transform( '. $TYPE .' )';
                eval $TYPE;
            }
        }
    }
    # FIXME: write typemap.unknown if unknown one(s) found
    exit 0;
}

=over

=item _lookup_type_in_super_class

Internal use only. Lookup a type throughout class' inheritance tree. 

return true and write super class name in $$ref_super_name if found;

return false on failure.

=back

=cut

sub _lookup_type_in_super_class {
    my ( $name, $type, $ref_super_name ) = @_;
    
    our ( %META_DICTIONARY, %TYPE_DICTIONARY, );
    # recursively look into all super classes
    # depth first
    if (exists $META_DICTIONARY{$name} and 
          exists $META_DICTIONARY{$name}->{ISA}) {
        foreach my $s (@{$META_DICTIONARY{$name}->{ISA}}) {
            my $super = $s->{NAME};
            if (exists $TYPE_DICTIONARY{$super} and 
                  exists $TYPE_DICTIONARY{$super}->{$type}) {
                $$ref_super_name = $super;
                return 1;
            }
            elsif (exists $META_DICTIONARY{$super} and 
                     exists $META_DICTIONARY{$super}->{ISA}) {
                my $result = _lookup_type_in_super_class(
                    $super, $type, $ref_super_name);
                return $result if $result;
            }
        }
    }
    return 0;
}

=over 

=item _lookup_type_in_parent_namespace

Internal use only. Lookup a type throughout parent namespaces.

return true and write parent namespace name in $$ref_parent_name if
found; 

return false on failure.

=back

=cut

sub _lookup_type_in_parent_namespace {
    my ( $name, $type, $ref_parent_name ) = @_;
    our ( %TYPE_DICTIONARY, );
    
    my @namespace = split /\:\:/, $name;
    pop @namespace;
    # A::B::C
    # lookup in A::B, A
    for (my $i = $#namespace; $i >= 0; $i--) {
        my $ns = join("::", @namespace[0 .. $i]);
        if (exists $TYPE_DICTIONARY{$ns} and 
              exists $TYPE_DICTIONARY{$ns}->{$type}) {
            $$ref_parent_name = $ns;
            return 1;
        }
    }
    return 0;
}

sub AUTOLOAD {
    our ( $NAMESPACE_DELIMITER, 
          $DEFAULT_NAMESPACE, $CURRENT_NAMESPACE, 
          %META_DICTIONARY, %TYPE_DICTIONARY, 
          %GLOBAL_TYPEMAP, %SIMPLE_TYPEMAP, %MANUAL_TYPEMAP, 
          @TYPE_UNKNOWN, );
    my $package = __PACKAGE__;
    ( my $autoload = $AUTOLOAD ) =~ s/^\Q$package\E(?:\:\:)?//o;
    my @namespace = split /\Q$NAMESPACE_DELIMITER\E/, $autoload;
    my $type_full = join("::", @namespace);
    my $type      = pop @namespace;
    # key to query into %TYPE_DICTIONARY
    # type with    namespace prefix: take its own namespace
    # type without namespace prefix: take the namespace within which
    #                                found the type
    my $namespace = @namespace ? join("::", @namespace) : 
      $CURRENT_NAMESPACE;
    # lookup order:
    # self
    # super classes (if has)
    # default_namespace
    # parent namespaces (experimental)
    # global_typemap && simple_typemap && manual_typemap
    my $super_name;
    if ($type eq 'enum_type') {
        # FIXME: lookup into %TYPE_DICTIONARY to verify
    }
    elsif (exists $TYPE_DICTIONARY{$namespace}->{$type}) {
    }
    elsif (_lookup_type_in_super_class(
        $namespace, $type, \$super_name)) {
        # located $type in $TYPE_DICTIONARY{$super_name}
    }
    elsif (exists $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type}) {
    }
    elsif (_lookup_type_in_parent_namespace(
        $namespace, $type, \$super_name)) {
        # located $type in $TYPE_DICTIONARY{$super_name}
    }
    elsif (exists $GLOBAL_TYPEMAP{$type_full} or 
             exists $SIMPLE_TYPEMAP{$type_full} or 
               exists $MANUAL_TYPEMAP{$type_full}) {
        # something like std::string
    }
    else {
        # unknown
        #print STDERR $type_full, "\n";
        push @TYPE_UNKNOWN, $type_full;
    }
}

&main;

