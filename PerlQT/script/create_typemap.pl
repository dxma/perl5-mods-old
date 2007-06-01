#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use YAML ();
use File::Spec ();
use Config qw/%Config/;
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

sub __usage {
    print STDERR << "EOU";
usage: $0 <module.conf> <typemap.ignore> <typemap.simple>
    <typemap.manual> <typemap.dep> <in_xscode_dir> [<out_typemap>]
EOU
    exit 1;
}

# internal use
our $AUTOLOAD;
our $TYPE;

our $NAMESPACE_DELIMITER = '__';
our $DEFAULT_NAMESPACE   = '';
# the namespace in which the type is involved
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

# for type transform: 
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

# for AUTOLOAD
sub PTR {
    my $entry = @_ ? shift : {};
    $entry->{IS_PTR} = 1;
    if (exists $entry->{type}) {
        # take existing type value
        # '(&|*)*' => 'PTR'
        # '(&|*)&' => 'REF'
        $entry->{c_type} = '*'. $entry->{c_type};
    }
    else {
        # new pointer structure
        $entry->{type}   = 'PTR';
        $entry->{c_type} = '*';
    }
    return $entry;
}
sub REF {
    my $entry = @_ ? shift : {};
    $entry->{IS_REF} = 1;
    if (exists $entry->{type}) {
        # take existing type value
        $entry->{c_type} = '&'. $entry->{c_type};
    }
    else {
        # new pointer structure
        $entry->{type}   = 'REF';
        $entry->{c_type} = '&';
    }
    return $entry;
}
# NOTE: char * const == char const *
sub const {
    my $entry = @_ ? shift : {};
    $entry->{IS_CONST} = 1;
    if (exists $entry->{type}) {
        $entry->{type}   = 'CONST_'. $entry->{type};
        $entry->{c_type} = 'const '. $entry->{c_type};
    }
    else {
        $entry->{type}   = 'CONST';
        $entry->{c_type} = 'const';
    }
    return $entry;
}
sub unsigned {
    my $entry = shift;
    $entry->{PREFERED_SV} = 'UV';
    return $entry;
}
sub signed {
    my $entry = shift;
    $entry->{PREFERED_SV} = 'IV';
    return $entry;
}
sub void {
    my $entry = @_ ? shift : {};
    if (exists $entry->{type}) {
        $entry->{type}   = 'T_GENERIC_'. $entry->{type};
        $entry->{c_type} = 'void '. $entry->{c_type};
    }
    else {
        $entry->{type}   = 'GENERIC';
        $entry->{c_type} = 'void';
    }
    return $entry;
}
# mask CORE::int later
my $my_int = sub {
    my $entry = @_ ? shift : {};
    my $prefered_sv = exists $entry->{PREFERED_SV} ?
      $entry->{PREFERED_SV} : 'IV';
    if (exists $entry->{type}) {
        $entry->{type}   = $prefered_sv. '_'. $entry->{type};
        $entry->{c_type} = 'int '. $entry->{c_type};
    }
    else {
        $entry->{type}   = $prefered_sv;
        $entry->{c_type} = 'int';
    }
    return $entry;
};

# QT template types
# invoke of each will instantiate new xs/pm code source files from
# specific templates 
# to serve requested template type
sub Q3PtrList {
    my $sub_entry = shift;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{child} = $sub_entry;
    $entry->{type}   = 'Q3PTRLIST_'. $sub_entry->{type};
    $entry->{c_type} = 'Q3PtrList< '. $sub_entry->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub Q3ValueList {
    my $sub_entry = shift;
    my $entry     = {};
    $entry->{IS_TEPLATE} = 1;
    $entry->{child} = $sub_entry;
    $entry->{type}   = 'Q3VALUELIST_'. $sub_entry->{type};
    $entry->{c_type} = 'Q3ValueList< '. $sub_entry->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QFlags {
    my $sub_entry = shift;
    my $entry     = {};
    $entry->{IS_TEPLATE} = 1;
    $entry->{child} = $sub_entry;
    $entry->{type}   = 'QFLAGS_'. $sub_entry->{type};
    $entry->{c_type} = 'QFlags< '. $sub_entry->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QList {
    my $sub_entry = shift;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{child} = $sub_entry;
    $entry->{type}   = 'QLIST_'. $sub_entry->{type};
    $entry->{c_type} = 'QList< '. $sub_entry->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QVector {
    my $sub_entry = shift;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{child} = $sub_entry;
    $entry->{type}   = 'QVECTOR_'. $sub_entry->{type};
    $entry->{c_type} = 'QVector< '. $sub_entry->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QSet {
    my $sub_entry = shift;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{child} = $sub_entry;
    $entry->{type}   = 'QSET_'. $sub_entry->{type};
    $entry->{c_type} = 'QSet< '. $sub_entry->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QMap {
    my ( $sub_key, $sub_value, ) = @_;
    my $entry                    = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{child} = [ $sub_key, $sub_value, ];
    $entry->{type}   = 
      join('_', 'QMAP'. $sub_key->{type}. $sub_value->{type});
    $entry->{c_type} = 'QMap< '. $sub_key->{c_type}. 
      ', '. $sub_value->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QMultiMap {
    my ( $sub_key, $sub_value, ) = @_;
    my $entry                    = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{child} = [ $sub_key, $sub_value, ];
    $entry->{type}   = 
      join('_', 'QMULTIMAP', $sub_key->{type}, $sub_value->{type});
    $entry->{c_type} = 'QMultiMap< '. $sub_key->{c_type}. 
      ', '. $sub_value->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}
sub QPair {
    my ( $first, $second, ) = @_;
    my $entry                    = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{child} = [ $first, $second, ];
    $entry->{type}   = 
      join('_', 'QPAIR', $first->{type}, $second->{type});
    $entry->{c_type} = 'QPair< '. $first->{c_type}. 
      ', '. $second->{c_type}. ' >';
    # FIXME: generate xs/pm files
    return $entry;
}

=over

=item __final_transform

Final step to identify the structure information of a type. 

return final transformed type structure. 

=back

=cut

sub __final_transform {
    my ( $primary, @optional ) = @_;
    foreach my $opt_entry (@optional) {
        # (nested) PTR/REF/CONST structure
        $primary->{type}   .= '_'. $opt_entry->{type};
        $primary->{c_type} .= ' '. $opt_entry->{c_type};
    }
    # FIXME: write to typemap
    #print STDERR $primary->{type}, "\t"x5, $primary->{c_type}, "\n";
    return $primary;
}

=over

=item __load_yaml

Internal use. Load a YAML-ish file and return its yaml-ed content.

=back

=cut

sub __load_yaml {
    my ( $f ) = @_;
    
    local ( *FILE, );
    open FILE, "<", $f or die "cannot open file: $!";
    my $cont = do { local $/; <FILE> };
    close FILE;
    my $hcont= YAML::Load($cont);
    return $hcont;
}

=over 

=item __read_typemap

Read supported type list inside a typemap file. Store each as a key of
hash passed-in. 

=back

=cut

sub __read_typemap {
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

=over

=item __analyse_type

Try to analyse a C/C++ type. Transform it into a group of function
calls. Return a self-deterministic structure to describe the type
information. 

=back

=cut

sub __analyse_type {
    our $TYPE = shift;
    our ( %GLOBAL_TYPEMAP, %SIMPLE_TYPEMAP, %MANUAL_TYPEMAP, );
    my $result;
    
    # simply normalize
    $TYPE =~ s/^\s+//gio;
    $TYPE =~ s/\s+$//gio;
    $TYPE =~ s/\s+/ /gio;
    if (exists $GLOBAL_TYPEMAP{$TYPE} or 
              exists $SIMPLE_TYPEMAP{$TYPE} or 
                exists $MANUAL_TYPEMAP{$TYPE}) {
        $result = {};
        $result->{type}   = 
          exists $GLOBAL_TYPEMAP{$TYPE} ? $GLOBAL_TYPEMAP{$TYPE} : 
            exists $SIMPLE_TYPEMAP{$TYPE} ? $SIMPLE_TYPEMAP{$TYPE} : 
              $MANUAL_TYPEMAP{$TYPE};
        $result->{c_type} = $TYPE;
    }
    else {
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
                  {$1.'('. ($2 eq '*' ? ' PTR' : ' REF'). ')' }gei) {
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
        $TYPE = '__final_transform( '. $TYPE .' )';
        {
            #print $TYPE, "\n";
            # mask built-in function 'int'
            local *CORE::GLOBAL::int = $my_int;
            $result = eval $TYPE;
            die "error while eval-ing type: $@" if $@;
        }
    }
    return $result;
}

sub main {
    __usage() if @ARGV < 6;
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
    my $hconf = __load_yaml($module_dot_conf);
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
        $META_DICTIONARY{$n} = __load_yaml($f);
    }
    # pre-cache all type info
    our %TYPE_DICTIONARY;
    foreach my $f (@typedef) {
        my @f = File::Spec::->splitdir($f);
        ( my $n = $f[-1] ) =~ s/\.typedef$//o;
        $n =~ s/\_\_/::/gio;
        $TYPE_DICTIONARY{$n} = __load_yaml($f);
    }
    # pre-cache all function info
    my %method = ();
    foreach my $t (qw/function signal slot/) {
        foreach my $f (@{$member{$t}}) {
            my @f = File::Spec::->splitdir($f);
            ( my $n = $f[-1] ) =~ 
              s/\.\Q$t\E(?:\.(?:public|protected))?$//;
            $n =~ s/\_\_/::/gio;
            $method{$t}->{$n} = __load_yaml($f);
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
    __read_typemap($global_typemap_file, \%GLOBAL_TYPEMAP);
    # locate those types which should be ignored
    __read_typemap($typemap_dot_ignore, \%IGNORE_TYPEMAP);
    # locate simple types
    __read_typemap($typemap_dot_simple, \%SIMPLE_TYPEMAP);
    # locate manual types
    __read_typemap($typemap_dot_manual, \%MANUAL_TYPEMAP);
    
    our $CURRENT_NAMESPACE;
    foreach my $n (keys %type) {
        #print STDERR "name: ", $n, "\n";
        $CURRENT_NAMESPACE = $n;
        foreach my $t (@{$type{$n}}) {
            unless (exists $IGNORE_TYPEMAP{$t}) {
                my $result = __analyse_type($t);
                # post patch:
                # void ** => T_GENERIC_PTR => T_PTR
                {
                    my $re_type = $result->{type};
                    $re_type =~ s/^T\_GENERIC\_PTR$/T_PTR/o;
                    $result->{type} = $re_type;
                }
                print $result->{type}, "\t"x5, $result->{c_type}, "\n";
            }
        }
    }
    # FIXME: write typemap.unknown if unknown one(s) found
    exit 0;
}

=over

=item __lookup_type_in_super_class

Internal use only. Lookup a type throughout class' inheritance tree. 

return true and write super class name in $$ref_super_name if found;

return false on failure.

=back

=cut

sub __lookup_type_in_super_class {
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
                my $result = __lookup_type_in_super_class(
                    $super, $type, $ref_super_name);
                return $result if $result;
            }
        }
    }
    return 0;
}

=over 

=item __lookup_type_in_parent_namespace

Internal use only. Lookup a type throughout parent namespaces.

return true and write parent namespace name in $$ref_parent_name if
found; 

return false on failure.

=back

=cut

sub __lookup_type_in_parent_namespace {
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
    # full type name
    my $type_full = join("::", @namespace);
    # short type name
    my $type      = pop @namespace;
    # key to query into %TYPE_DICTIONARY :
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
    # structure to return
    my $entry = {};
    my $TYPE_ENUM            = 'T_ENUM';
    my $TYPE_FPOINTER_PREFIX = 'T_FPOINTER_';
    if ($type eq 'enum_type') {
        # QFlags template type
        my $template_type      = $namespace[-1];
        my $template_namespace = join("::", @namespace[0 .. $#namespace-1]);
        # lookup into %TYPE_DICTIONARY to verify
#         if (exists $TYPE_DICTIONARY{$template_namespace} and 
#               exists
#                 $TYPE_DICTIONARY{$template_namespace}->{$template_type}) {
#         }
        $entry->{type}   = $TYPE_ENUM;
        $entry->{c_type} = join("::", 
                                $template_namespace, $template_type);
    }
    elsif (exists $TYPE_DICTIONARY{$namespace}->{$type}) {
        $entry->{type}   = $TYPE_DICTIONARY{$namespace}->{$type};
        $entry->{c_type} = $type_full;
    }
    elsif (__lookup_type_in_super_class(
        $namespace, $type, \$super_name)) {
        # located $type in $TYPE_DICTIONARY{$super_name}
        # function pointer: prototype string from 
        # $TYPE_DICTIONARY{$super_type}->{ 
        #     $TYPE_DICTIONARY{$super_name}->{$type} }
        $entry->{type}   = $TYPE_DICTIONARY{$super_name}->{$type};
        if ($entry->{type} !~ m/^\Q$TYPE_FPOINTER_PREFIX\E/o) {
            $entry->{c_type} = $type_full;
        }
        else {
            $entry->{c_type} = $TYPE_DICTIONARY{$super_name}->{ 
                $TYPE_DICTIONARY{$super_name}->{$type} };
        }
    }
    elsif (exists $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type}) {
        $entry->{type}   =
          $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type};
        if ($entry->{type} !~ m/^\Q$TYPE_FPOINTER_PREFIX\E/o) {
            $entry->{c_type} = $type_full;
        }
        else {
            $entry->{c_type} = $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{
                $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type} };
        }
    }
    elsif (__lookup_type_in_parent_namespace(
        $namespace, $type, \$super_name)) {
        # located $type in $TYPE_DICTIONARY{$super_name}
        $entry->{type}   = $TYPE_DICTIONARY{$super_name}->{$type};
        if ($entry->{type} !~ m/^\Q$TYPE_FPOINTER_PREFIX\E/o) {
            $entry->{c_type} = $type_full;
        }
        else {
            $entry->{c_type} = $TYPE_DICTIONARY{$super_name}->{ 
                $TYPE_DICTIONARY{$super_name}->{$type} };
        }
    }
    elsif (exists $GLOBAL_TYPEMAP{$type_full} or 
             exists $SIMPLE_TYPEMAP{$type_full} or 
               exists $MANUAL_TYPEMAP{$type_full}) {
        # NOTE: something like std::string
        $entry->{type}   = 
          exists $GLOBAL_TYPEMAP{$type_full} ?
            $GLOBAL_TYPEMAP{$type_full} : 
              exists $SIMPLE_TYPEMAP{$type_full} ? 
                $SIMPLE_TYPEMAP{$type_full} : 
                  $MANUAL_TYPEMAP{$type_full};
        $entry->{c_type} = $type_full;
    }
    else {
        # unknown
        print STDERR "unknown type: ", $type_full, "\n";
        $entry->{type}   = 'UNKNOWN_FIXME';
        $entry->{c_type} = 'UNKNOWN_FIXME';
        push @TYPE_UNKNOWN, $type_full;
    }
    return $entry;
}

&main;

