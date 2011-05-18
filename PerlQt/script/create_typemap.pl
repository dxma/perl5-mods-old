#! /usr/bin/perl -w
# Author: Dongxu Ma

use warnings;
no warnings 'once';
use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT);
use File::Spec ();
use Config qw/%Config/;
use FindBin      ();
use Data::Dumper ();
# make sure typemap exists
use ExtUtils::MakeMaker ();

use YAML::Syck qw(Load Dump);
use Parse::RecDescent ();

=head1 DESCRIPTION

Create typemap according to all relevant source: 

<module>.{function.public, function.protected, signal, slot.public,
slot.protected} and <module>.typedef

B<NOTE>: Connect each involved C++ type (either function parameter
type or function return type) to known typemap slot; Record unknown
ones into typemap.unknown

=cut

sub __usage {
    print STDERR << "EOU";
usage: $0 <module.conf> <typemap.ignore> <typemap.simple>
    <typemap.manual> <typemap.dep> <out_typemap_dir> <typemap_template> [<typemap_list>]
EOU
    exit 1;
}

# internal use
our $AUTOLOAD;
our $TYPE;

our $NAMESPACE_DELIMITER = '___';
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
# hash to hold all known type(s)
our %TYPE_KNOWN      = ();
# array to hold any unknown type(s)
our @TYPE_UNKNOWN    = ();
# array to hold all template type(s)
our @TYPE_TEMPLATE   = ();
# shadow cache
our %_TYPE_TEMPLATE  = ();
# hash to hold all local type name 
# and corresponding full qualified name
our %TYPE_LOCALMAP   = ();

# for type transform: 
# const takes one additional parameter
# a tiny Parse::RecDescent grammar to work on
# grabbing const parameter
my $const_grammar = q{
    start : next_const const_body const_other 
            { $main::TYPE = $item[1]->[1]. "( ". $item[2]. " ) ". $item[3]; }
            { if ($item[2] eq '') { 
                  # something like 'QMenuBar * const'
                  $main::TYPE = $item[1]->[0].", ".$main::TYPE;
              } else {
                  $main::TYPE = $item[1]->[0]. $main::TYPE;
              }
            }
    const_other            : m/^(.*)\Z/o      { $return = $1; } 
                           | { $return = ''; }
    next_const             : m/^(.*?)\b(const)\b(?!\_)\s*(?!\()/o 
                             { $return = [$1, $2]; } 
    const_body_simple      : m/([^()*&]+)/io { $return = $1; }  
    next_const_body_token  : m/([^()]+)/io   { $return = $1; } 
    const_body     : const_body_simple ...!'(' { $return = $item[1]; }
                   | const_body_loop           { $return = $item[1]; } 
                   |                           { $return = '';       }
    const_body_loop: next_const_body_token 
                     ( '(' <commit> const_body_loop ')' ( const_body_simple { $return = $item[1]; } | { $return = '' } ) 
                       { $return = $item[1]. $item[3]. $item[4]. $item[5]; } 
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
        # '&&'     => 'REF'
        # CAUTION:
        # '*&'     => 'REF'
        $entry->{type} = 'REF' if $entry->{type} eq 'REF';
        $entry->{c_type} = '*'. $entry->{c_type};
    }
    else {
        # new pointer structure
        $entry->{type}   = 'PTR';
        $entry->{c_type} = '*';
        $entry->{t_type} = 'PTR';
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
        $entry->{t_type} = 'REF';
    }
    return $entry;
}
# NOTE: const struct timeval
#       self-explaining, mark as T_STRUCT
sub struct {
    my $name = shift;
    my $entry = {};
    $entry->{type}   = 'T_STRUCT';
    $entry->{c_type} = 'struct '. $name;
    $entry->{t_type} = 'T_STRUCT';
    return $entry;
}
# NOTE: char * const == char const *
sub const {
    my $entry = @_ ? shift : {};
    if (exists $entry->{type}) {
        $entry->{type}   = 'CONST_'. $entry->{type};
        $entry->{c_type} = 'const '. $entry->{c_type};
        $entry->{t_type} = 'CONST_'. $entry->{t_type};
    }
    else {
        $entry->{type}   = 'CONST';
        $entry->{c_type} = 'const';
        $entry->{t_type} = 'CONST';
        $entry->{IS_CONST} = 1;
    }
    return $entry;
}
sub unsigned {
    my $entry = @_ ? shift : {};
    if (exists $entry->{type}) {
        my $type = $entry->{type};
        $type =~ s/T\_IV/T_UV/go;
        $entry->{type}   = $type;
        my $ttype = $entry->{t_type};
        $ttype =~ s/T\_IV/T_UV/go;
        $entry->{t_type} = $ttype;
        $entry->{c_type} = 'unsigned '. $entry->{c_type};
    }
    else {
        $entry->{type}   = 'T_UV';
        $entry->{c_type} = 'unsigned';
        $entry->{t_type} = 'T_UV';
    }
    return $entry;
}
sub signed {
    my $entry = shift;
    my $type = $entry->{type};
    $type =~ s/T\_UV/T_IV/go;
    $entry->{type}   = $type;
    my $ttype = $entry->{t_type};
    $ttype =~ s/T\_UV/T_IV/go;
    $entry->{t_type} = $ttype;
    $entry->{c_type} = 'signed '. $entry->{c_type};
    return $entry;
}
sub void {
    my $entry = @_ ? shift : {};
    if (exists $entry->{type}) {
        $entry->{type}   = 'T_GENERIC_'. $entry->{type};
        $entry->{c_type} = 'void '. $entry->{c_type};
        $entry->{t_type} = 'T_GENERIC_'. $entry->{t_type};
    }
    else {
        $entry->{type}   = 'T_GENERIC';
        $entry->{c_type} = 'void';
        $entry->{t_type} = 'T_GENERIC';
    }
    return $entry;
}
# mask CORE::int later
my $my_int = sub {
    my $entry = @_ ? shift : {};
    if (exists $entry->{type}) {
        $entry->{type}   = 'T_IV_'. $entry->{type};
        $entry->{c_type} = 'int '. $entry->{c_type};
        $entry->{t_type} = 'T_IV_'. $entry->{t_type};
    }
    else {
        $entry->{type}   = 'T_IV';
        $entry->{c_type} = 'int';
        $entry->{t_type} = 'T_IV';
    }
    return $entry;
};

# load custom AUTOLOAD methods
BEGIN { require "$FindBin::Bin/create_typemap_custom_methods.pl"; }

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
    return $primary;
}

=over

=item __load_yaml

Internal use. Load a YAML-ish file and return its yaml-ed content.

=back

=cut

sub __load_yaml {
    my ( $f ) = @_;
    
    #print STDERR $f, "\n";
    local ( *FILE, );
    open FILE, "<", $f or die "cannot open file $f: $!";
    #print STDERR "loading file: $f\n";
    my $cont = do { local $/; <FILE> };
    close FILE;
    my $hcont= Load($cont);
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
        last if /^INPUT\s*$/o;
        next if /^\s*#/io;
        next if /^\s*$/io;
        next if /^TYPEMAP\s*$/o;
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

B<NOTE>: the self-deterministic structure is basically a hash with
three fundamental keys - 'type', 'c_type' and 't_type'. The value of
'type' corresponses to the final typemap string. The value of 'c_type'
is the raw C/C++ type string. The value of 't_type' is _ONLY_ used by 
template types to form the specific typemap name. 

=back

=cut

sub __analyse_type {
    local $TYPE = shift;
    our ( %GLOBAL_TYPEMAP, %SIMPLE_TYPEMAP, %MANUAL_TYPEMAP, 
          $CURRENT_NAMESPACE, %TYPE_LOCALMAP, );
    my ( $result, $type_full, );
    
    # $type_full: full qualified type name (with namespace)
    # FIXME: doesn't apply to simple c type like int etc.
    if ($TYPE =~ m/::(?>[^<>]+)$/io) {
        $type_full = $TYPE;
    }
    else {
        $type_full = join("::", $CURRENT_NAMESPACE, $TYPE);
    }
    #print STDERR $TYPE, " -> ", $type_full, "\n";
    if (exists $GLOBAL_TYPEMAP{$TYPE} or 
              exists $SIMPLE_TYPEMAP{$TYPE}) {
        $result = {};
        $result->{type}   = exists $GLOBAL_TYPEMAP{$TYPE} ? 
          $GLOBAL_TYPEMAP{$TYPE} : $SIMPLE_TYPEMAP{$TYPE};
        $result->{c_type} = $TYPE;
        $result->{t_type} = $result->{type};
    }
    elsif (exists $MANUAL_TYPEMAP{$type_full}) {
        # might be a private type in that class
        $result = {};
        $result->{type}   = $MANUAL_TYPEMAP{$type_full};
        $result->{c_type} = $type_full;
        $result->{t_type} = $result->{type};
        ( my $ns = $CURRENT_NAMESPACE ) =~ s/\:\:/__/go;
        $TYPE_LOCALMAP{$ns}->{$TYPE} = $type_full;
    }
    else {
        #print STDERR "orig  : ", $TYPE, "\n";
        my $call_transform = sub {
            my $type = shift;
            
            $type = '__final_transform( '. $type .' )';
            #print STDERR $type, "\n";
            # mask built-in function 'int'
            local *CORE::GLOBAL::int = $my_int;
            my $ret = eval $type;
            die "error while eval-ing type '$type': $@" if $@;
            return $ret;
        };
        # transforms
        # template to a function call
        # '<' => '('
        $TYPE =~ s/\</(/gio;
        # '>' => ')'
        $TYPE =~ s/\>/)/gio;
        # 'Template<A>::Type' => 'Template<A>->Type'
        $TYPE =~ s/\)::/)->/io;
        # FIXME:
        # '* const *' => '* *'
        $TYPE =~ s{(.*)\*\s+const\s+\*}{$1 * *}gio;
        # recursively process any bare 'const' word
        # skip processed and something like 'const_iterator'
        while ($TYPE =~ m/\bconst\b(?!\_)\s*(?!\()/o) {
            defined $parser->start($TYPE) or die "Parse failed!";
        }
        #print STDERR "patch1: ", $TYPE, "\n";
        # transform rule for coutinous (two or more) 
        # pointer ('*') or reference ('&')
        # * (*|&) => PTR (PTR|REF)
        # which means second will ALWAYS be a parameter of 
        # the first
        # for instance:
        # '* & *' => 'PTR( REF( PTR ))'
        # FIRST GREDDY IS IMPORTANT
        while ($TYPE =~ 
                 s{(.*(?<=(?:\*|\&)))\s*(\*|\&)}
                  {$1.'('. ($2 eq '*' ? 'PTR' : 'REF'). ')' }geio) {
            1;
        }
        # leading or standalone pointer or reference
        # '*' => ', PTR'
        $TYPE =~ s/\*/, PTR/gio;
        # '&' => ', REF'
        $TYPE =~ s/\&/, REF/gio;
        # transform signed|unsigned
        # 'signed long' => 'signed( long )'
        $TYPE =~ s/\b((?:un)?signed)\s+((?>[^ ]+))/$1($2)/go;
        # 'const struct timeval' => 'const struct'
        $TYPE =~ s/\bstruct ([A-Z_a-z_0-9_\_]+)/struct($1)/go;
        # mask bareword as a function call without any
        # parameter
        #print STDERR "patch2: ", $TYPE, "\n";
        $TYPE =~ s/\b([A-Z_a-z_\_]+\w+)\b(?<!signed)(?!(?:\(|\:))/$1()/go;
        # patch struct(foo()) back to struct('foo')
        $TYPE =~ s/\bstruct\(([A-Z_a-z_0-9_\_]+)\(\)\)/struct('$1')/go;
        # '::' to $NAMESPACE_DELIMITER
        our $NAMESPACE_DELIMITER;
        $TYPE =~ s/\:\:/$NAMESPACE_DELIMITER/gio;
        $TYPE =~ s/\bstd\Q$NAMESPACE_DELIMITER\E(?!(?:string|istream|ostream))/std_/go;
        #print STDERR "patch3: ", $TYPE, "\n";
        $result = $call_transform->($TYPE);
    }
    #print STDERR "final : ", $result->{c_type}, " => ", $result->{t_type}, "\n";
    return $result;
}

sub main {
    __usage() if @ARGV < 7;
    # FIXME: GetOpt::Long
    #        see script/gen_xscode_mk.pl
    my ( $module_dot_conf, 
         $typemap_dot_ignore, $typemap_dot_simple,
         $typemap_dot_manual, $typemap_dot_dep, 
         $out_typemap_dir, 
         $out_template, $out_list ) = @ARGV;
    my $rc = 0;
    
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
    die "dir $out_typemap_dir not found" unless 
      -d $out_typemap_dir;
    
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
            elsif (m/\.(function)\.(?:public)$/o) {
                push @{$member{$1}}, $_;
            } 
            elsif (m/\.(signal)$/o) {
                push @{$member{$1}}, $_;
            } 
            elsif (m/\.(slot)\.(?:public)$/o) {
                push @{$member{$1}}, $_;
            } 
            elsif (m/\.(fpointer)$/o) {
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
    our %TYPE_KNOWN;
    foreach my $f (@typedef) {
        my @f = File::Spec::->splitdir($f);
        ( my $n = $f[-1] ) =~ s/\.typedef$//o;
        $n =~ s/\_\_/::/gio;
        $TYPE_DICTIONARY{$n} = __load_yaml($f);
        # cache anonymous class/enum into known type directly
        foreach my $c (keys %{$TYPE_DICTIONARY{$n}}) {
            next if $c =~ /^T_/o;
            if ($TYPE_DICTIONARY{$n}->{$c} =~ /^T_/o) {
                if ($n eq $DEFAULT_NAMESPACE) {
                    $TYPE_KNOWN{$c} = $TYPE_DICTIONARY{$n}->{$c};
                }
                else {
                    $TYPE_KNOWN{$n. '::'. $c} = $TYPE_DICTIONARY{$n}->{$c};
                }
            }
        }
    }
    # pre-cache all function info
    my %method = ();
    foreach my $t (qw/function signal slot fpointer/) {
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
          %MANUAL_TYPEMAP, 
          @TYPE_UNKNOWN, %TYPE_LOCALMAP, @TYPE_TEMPLATE, );
    # locate all known types from global typemap
    my $global_typemap_file = File::Spec::->catfile(
        $Config{privlib}, 'ExtUtils', 'typemap');
    #__read_typemap($global_typemap_file, \%GLOBAL_TYPEMAP);
    # locate those types which should be ignored
    __read_typemap($typemap_dot_ignore, \%IGNORE_TYPEMAP);
    # locate simple types
    __read_typemap($typemap_dot_simple, \%SIMPLE_TYPEMAP);
    # locate manual types
    __read_typemap($typemap_dot_manual, \%MANUAL_TYPEMAP);
    # if typemap.manual.something exists, load them into
    # MANUAL_TYPEMAP
    if (my @typemap_dot_manual = glob($typemap_dot_manual. ".*")) {
        foreach my $f (@typemap_dot_manual) {
            my $manual_typemap = __load_yaml($f, \%MANUAL_TYPEMAP);
            foreach my $k (keys %$manual_typemap) {
                $MANUAL_TYPEMAP{$k} = $manual_typemap->{$k};
            }
        }
    }
    
    my $post_patch_type = sub {
        my ( $result, ) = @_;
        
        my $re_type = $result->{type};
        # post patch:
        # void ** => T_GENERIC_PTR => T_PTR
        # T_CLASS_CONST => CONST_T_CLASS
        # ::            => ___
        $re_type =~ s/^T\_GENERIC\_PTR$/T_PTR/o;
        $re_type =~ s/^(.*)\_CONST$/CONST_$1/o;
        $re_type =~ s/\:\:/___/go;
        $result->{type} = $re_type;
    };
    
    our $CURRENT_NAMESPACE;
    foreach my $n (keys %type) {
        #print STDERR "name: ", $n, "\n";
        $CURRENT_NAMESPACE = $n;
        TYPE_LOOP:
        foreach my $t (@{$type{$n}}) {
            unless (exists $IGNORE_TYPEMAP{$t}) {
                next TYPE_LOOP if exists $TYPE_KNOWN{$t};
                my $result = __analyse_type($t);
                $post_patch_type->($result);
                $TYPE_KNOWN{$result->{c_type}} = $result->{type};
                if ($result->{c_type} ne $t) {
                    # maybe a typedef or local type without class name
                    # record it in local map
                    ( my $ns = $CURRENT_NAMESPACE ) =~ s/\:\:/__/go;
                    $TYPE_LOCALMAP{$ns}->{$t} = $result->{c_type};
                }
                #print STDERR $t, " resolved as  : ", $result->{type}, "\n";
            }
        }
    }
    # add all existing classes
    foreach my $k (keys %META_DICTIONARY) {
        my $meta = $META_DICTIONARY{$k};
        if ($meta->{TYPE} eq 'class') {
            $TYPE_KNOWN{$meta->{NAME}} = 'T_CLASS';
        }
    }
    # write typemap list
    my $hcont_typemap_list = Dump(\%TYPE_KNOWN);
    if (defined $out_list) {
        local ( *OUT, *UNKNOWN, );
        sysopen OUT, $out_list, O_CREAT|O_WRONLY|O_TRUNC or 
          die "cannot open file to write: $!";
        print OUT $hcont_typemap_list;
        close OUT or die "cannot save to file: $!";
        # write typemap.unknown if unknown one(s) found
        if (@TYPE_UNKNOWN) {
            sysopen UNKNOWN, $out_list. '.unknown', O_CREAT|O_WRONLY|O_TRUNC or 
              die "cannot open file to write: $!";
            foreach (@TYPE_UNKNOWN) {
                print UNKNOWN $_;
            }
            close UNKNOWN or die "cannot save to file: $!";
            $rc = 1;
        }
    }
    else {
        print STDOUT $hcont_typemap_list;
    }
    # figure out inner type for each template class
    $CURRENT_NAMESPACE = '';
    TYPE_TEMPLATE_LOOP:
    foreach my $template_class (@TYPE_TEMPLATE) {
        TEMPLATE_CLASS_LOOP:
        foreach my $k (keys %$template_class) {
            next TEMPLATE_CLASS_LOOP unless 
              $k =~ m/\_type$/o;
            my $type = $template_class->{$k};
            unless (exists $IGNORE_TYPEMAP{$type}) {
                ( my $k_type = $k ) =~ s/type$/ntype/o;
                if (exists $TYPE_KNOWN{$type}) {
                    # already found
                    $template_class->{$k_type} = 
                      $TYPE_KNOWN{$type};
                }
                else {
                    # call analyse_type
                    #print STDERR "template type: $type\n";
                    my $result = __analyse_type($type);
                    $post_patch_type->($result);
                    $template_class->{$k_type} = 
                      $result->{type};
                    $TYPE_KNOWN{$result->{c_type}} = 
                      $result->{type};
                }
            }
        }
    }
    # write @TYPE_TEMPLATE
    if (@TYPE_TEMPLATE) {
        local ( *TEMPLATE, );
        sysopen TEMPLATE, $out_template, O_CREAT|O_WRONLY|O_TRUNC or 
          die "cannot open file to write: $!";
        my ( $hcont ) = Dump(\@TYPE_TEMPLATE);
        print TEMPLATE $hcont;
        close TEMPLATE or die "cannot save to file: $!";
    }
    # write %TYPE_LOCALMAP
    if (keys %TYPE_LOCALMAP) {
        local ( *LOCALMAP, );
        foreach my $ns (keys %TYPE_LOCALMAP) {
            my $localmap = File::Spec::->catfile($out_typemap_dir, 
                                                 $ns. ".typemap");
            sysopen LOCALMAP, $localmap, O_CREAT|O_WRONLY|O_TRUNC or 
              die "cannot open file to write: $!";
            my ( $hcont ) = Dump($TYPE_LOCALMAP{$ns});
            print LOCALMAP $hcont;
            close LOCALMAP or die "cannot save to file: $!";
        }
    }
    exit $rc;
}

=over

=item __lookup_type_in_super_class

Internal use only. Lookup a type throughout class inheritance tree. 

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
    my $TYPE_ARRAY_PREFIX    = 'T_ARRAY_';
    my $store_type_info_from_dictionary = sub {
        my ( $namespace_key, $type, $type_full, $entry, ) = @_;
        
        my $regex_fpointer_or_array = 
          qr/^(?:\Q$TYPE_FPOINTER_PREFIX\E|\Q$TYPE_ARRAY_PREFIX\E)/o;
        if ($type =~ $regex_fpointer_or_array) {
            # $type itself is already something like 
            # T_FPOINTER_BLAH 
            # processed by script/format_qtedi_production.pl
            # such case is _NOT_ typedefed
            # locate its prototype in %TYPE_DICTINOARY
            $entry->{type}   = $type_full;
            $entry->{c_type} = $type_full;
            # $entry->{c_type} =
            #   $TYPE_DICTIONARY{$namespace_key}->{$type};
            $entry->{t_type} = $type_full;
        }
        else {
            $entry->{type} =
              $TYPE_DICTIONARY{$namespace_key}->{$type};
            #print STDERR "$type: ", $entry->{type}, "\n";
            if ($entry->{type} !~ m/^(?:CONST_)?T_[A-Z_0-9_\_]+$/o) { 
                # not constructed by primitive type and 
                # property such as: PTR/REF/CONST
                # recursively lookup
                # walkthrough all possible typedef alias
                # to get final primitive type
                #print "from : ", $type_full, "\n";
                #print "to   : ", $entry->{type}, "\n";
                # by default lookup in namespace $namespace_key
                local $CURRENT_NAMESPACE = $namespace_key;
                my $i = 0;
                while ($entry->{type} !~ m/^(?:CONST_)?T_[A-Z_0-9_\_]+$/o) {
                    die "deep recursive loop detected for type ". 
                      $namespace_key. '::'. $entry->{type} if $i == 50;
                    my $result = __analyse_type($entry->{type});
                    for my $k (keys %$result) {
                        $entry->{$k} = $result->{$k};
                    }
                    #use Data::Dumper;
                    #print Data::Dumper::Dumper($entry);
                    #exit 0;
                    $i++;
                }
            }
            elsif ($entry->{type} =~ $regex_fpointer_or_array) {
                # bridged-typedef 
                # inside %TYPE_DICTIONARY there are two related entries:
                # 1. $type           => T_FPOINTER_BLAH
                # 2. T_FPOINTER_BLAH => c prototype
                #$entry->{c_type} = $TYPE_DICTIONARY{$namespace_key}->{ 
                #    $entry->{type} };
                $entry->{c_type} = $type_full;
                $entry->{t_type} = $entry->{type};
                # $type same as $type_full this case
                if ($CURRENT_NAMESPACE ne $DEFAULT_NAMESPACE) {
                    # skip type in default namespace
                    if (!exists $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type_full}) {
                        # change c_type to full qualified name
                        $type_full = 
                          join("::", $CURRENT_NAMESPACE, $type_full);
                        $entry->{c_type} = $type_full;
                        ( my $ns = $CURRENT_NAMESPACE ) =~ s/\:\:/__/go;
                        $TYPE_LOCALMAP{$ns}->{$type} = $type_full;
                    }
                }
            }
            else {
                $entry->{c_type} = $type_full;
                ( my $t_type = $type_full ) =~ s/::/__/go;
                $entry->{t_type} = uc($t_type);
                if ($namespace_key ne $DEFAULT_NAMESPACE and 
                      $type_full !~ m/\:\:/io) {
                    # located local type $type in namespace typedef
                    # $type same as $type_full this case
                    # change c_type to full qualified name
                    $type_full = 
                      join("::", $namespace_key, $type_full);
                    $entry->{c_type} = $type_full;
                    ( my $ns = $CURRENT_NAMESPACE ) =~ s/\:\:/__/go;
                    $TYPE_LOCALMAP{$ns}->{$type} = $type_full;
                }
                #use Data::Dumper;
                #print STDERR Data::Dumper::Dumper($entry), "\n";
            }
        }
    };
    
    #print STDERR "$CURRENT_NAMESPACE => $namespace :: $type => $type_full\n";
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
                                $template_namespace, $template_type, $type);
        $entry->{t_type} = $TYPE_ENUM;
        #use Data::Dumper;
        #print STDERR Data::Dumper::Dumper($entry);
    }
    elsif (exists $TYPE_DICTIONARY{$namespace}->{$type}) {
        #print STDERR $type, ' => ', $TYPE_DICTIONARY{$namespace}->{$type}, "\n";
        $store_type_info_from_dictionary->($namespace, 
                                           $type, $type_full, $entry);
    }
    elsif ($namespace ne $CURRENT_NAMESPACE and 
             exists $TYPE_DICTIONARY{$CURRENT_NAMESPACE}->{$namespace[0]}) {
        # A::B where A is typedef in current class
        #print STDERR $namespace, ' => ', $TYPE_DICTIONARY{$CURRENT_NAMESPACE}->{$namespace[0]}, "\n";
        $store_type_info_from_dictionary->($CURRENT_NAMESPACE,
                                           $namespace, 
                                           $CURRENT_NAMESPACE. '::'. $namespace,
                                           $entry);
        $TYPE_KNOWN{$CURRENT_NAMESPACE. '::'. $namespace} = $entry->{t_type};
        # now lookup the inner type again
        my @namespace2 = @namespace;
        shift @namespace2;
        push @namespace2, $type;
        my $type_full2 = $entry->{c_type}. '::'. 
          join('::', @namespace2);
        #print STDERR $type_full, ' => ', $type_full2, "\n";
        my $result = __analyse_type($type_full2);
        #print STDERR $type_full, ' => ', $result->{t_type}, "\n";
        for my $k (keys %$result) {
            $entry->{$k} = $result->{$k};
        }
    }
    elsif (__lookup_type_in_super_class(
        $namespace, $type, \$super_name)) {
        # located $type in $TYPE_DICTIONARY{$super_name}
        $store_type_info_from_dictionary->($super_name, 
                                           $type, $type_full, $entry);
    }
    elsif (exists $TYPE_DICTIONARY{$DEFAULT_NAMESPACE}->{$type}) {
        $store_type_info_from_dictionary->($DEFAULT_NAMESPACE, 
                                           $type, $type_full, $entry);
    }
    elsif (__lookup_type_in_parent_namespace(
        $namespace, $type, \$super_name)) {
        # located $type in $TYPE_DICTIONARY{$super_name}
        $store_type_info_from_dictionary->($super_name, 
                                           $type, $type_full, $entry);
    }
    elsif (exists $GLOBAL_TYPEMAP{$type_full} or 
             exists $SIMPLE_TYPEMAP{$type_full}) {
        $entry->{type}   = 
          exists $GLOBAL_TYPEMAP{$type_full} ?
            $GLOBAL_TYPEMAP{$type_full} : $SIMPLE_TYPEMAP{$type_full};
        $entry->{c_type} = $type_full;
        ( my $t_type = $type_full ) =~ s/::/__/go;
        $entry->{t_type} = uc($t_type);
    }
    elsif (exists $MANUAL_TYPEMAP{$type_full}) {
        $entry->{type}   = $MANUAL_TYPEMAP{$type_full};
        $entry->{c_type} = $type_full;
        ( my $t_type = $type_full ) =~ s/::/__/go;
        $entry->{t_type} = uc($t_type);
        ( my $ns = $CURRENT_NAMESPACE ) =~ s/\:\:/__/go;
        #$TYPE_LOCALMAP{$ns}->{$type} = $type_full;
    }
    elsif (exists $MANUAL_TYPEMAP{
        join("::", $namespace, $type_full)}) {
        # NOTE: something like std::string
        # possibly a private class/struct inside class/struct
        $type_full = join("::", $namespace, $type_full);
        $entry->{type}   = $MANUAL_TYPEMAP{$type_full};
        $entry->{c_type} = $type_full;
        ( my $t_type = $type_full ) =~ s/::/__/go;
        $entry->{t_type} = uc($t_type);
        ( my $ns = $CURRENT_NAMESPACE ) =~ s/\:\:/__/go;
        $TYPE_LOCALMAP{$ns}->{$type} = $type_full;
    }
    else {
        # unknown
        print STDERR "unknown type: ", $type, " in ", $namespace, "\n";
        $entry->{type}   = 'UNKNOWN_FIXME';
        $entry->{c_type} = 'UNKNOWN_FIXME';
        $entry->{t_type} = 'UNKNOWN_FIXME';
        push @TYPE_UNKNOWN, $type_full;
    }
    #use Data::Dumper;
    #print STDERR Data::Dumper::Dumper($entry);
    return $entry;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
