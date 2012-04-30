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

my %OPERATOR_MAP = (
    '='   => 'assign',
    '+'   => 'add',
    '-'   => 'min',
    '*'   => 'mul',
    '/'   => 'div',
    '%'   => 'mod',
    '++'  => 'incr',
    '--'  => 'decr',
    '=='  => 'equal_to',
    '!='  => 'not_equal',
    '<'   => 'lt',
    '>'   => 'gt',
    '<='  => 'le',
    '>='  => 'ge',
    '!'   => 'not',
    '&&'  => 'and',
    '||'  => 'or',
    '~'   => 'bit_not',
    '&'   => 'bit_and',
    '|'   => 'bit_or',
    '^'   => 'bit_xor',
    '<<'  => 'bit_left',
    '>>'  => 'bit_right',
    '+='  => 'add_assign',
    '-='  => 'min_assign',
    '*='  => 'mul_assign',
    '/='  => 'div_assign',
    '%='  => 'mod_assign',
    '&='  => 'bit_and_assign',
    '|='  => 'bit_or_assign',
    '^='  => 'bit_not_assign',
    '<<=' => 'bit_left_assign',
    '>>=' => 'bit_right_assign',
    '[]'  => 'array',
    '()'  => 'funct',
    # FIXME
    #'*'   => 'deref',
    #'&'   => 'ref',
    '->'  => 'mem_of_ptr',
    '.'   => 'mem_of_obj',
    ','   => 'comma',
    'new'      => 'alloc',
    'delete'   => 'del',
    'new[]'    => 'alloc_array',
    'delete[]' => 'del_array',
);

=head1 DESCRIPTION

Create <module>.xs according to
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

# method copied from script/finalize_typemap.pl
sub get_known_primitive_types {
    my ( $type_template, ) = @_;

    local ( *TEMPLATE, );
    open TEMPLATE, '<', $type_template or
      croak("cannot open file to read: $!");
    my $primitive_type_map = {};
    while (<TEMPLATE>) {
        if (m/^\s*\[\%-?\s+CASE\s+(.+)\s+-?\%\]\s*$/o) {
            next if $1 eq 'DEFAULT';
            my $str = $1;
            if ($str =~ /^'([^']+)'$/o) {
                $primitive_type_map->{$1}++;
            }
            elsif ($str =~ /^\[\s*(.+)\s*\]$/o) {
                my $str2 = $1;
                foreach my $t (split /\s*,\s*/, $str2) {
                    if ($t =~ /^'([^']+)'$/o) {
                        $primitive_type_map->{$1}++;
                    }
                }
            }
            else {
                carp("unknown CASE line in typemap: ". $_);
            }
        }
    }
    close TEMPLATE;
    return $primitive_type_map;
}

sub create_xs_code {
    my %opt = @_;
    my $mod_conf             = $opt{mod_conf};
    my $meta                 = $opt{meta};
    my $publics              = $opt{publics};
    my $typemap              = $opt{typemap};
    my $typemap_template     = $opt{typemap_template};
    my $packagemap           = $opt{packagemap};
    my $enums                = $opt{enums};
    my $enummap              = $opt{enummap};
    my $known_primitive_type = $opt{known_primitive_type};
    my $abstract_class       = $opt{abstract_class};
    my $localtype            = $opt{localtype};
    my $def_typedef          = $opt{def_typedef};
    my $template             = $opt{template};
    my $subst_with_fullname  = $opt{subst_with_fullname};

    my $out = '';
    my $has_operator_new = 0;
    # loop into each public method, group by name
    my $pub_methods_by_name = {};
    my $skip_methods = exists $mod_conf->{skip_methods} ?
      $mod_conf->{skip_methods} : [];
    METHOD_LOOP:
    foreach my $i (@$publics) {
        # convert relevant field key to lowcase
        # no conflict with template commands
        my $name         = delete $i->{NAME};
        $has_operator_new = 1 if $name eq 'operator new';
        next METHOD_LOOP if grep { $name eq $_ } @$skip_methods;
        next METHOD_LOOP if grep { $meta->{NAME}. '::'. $name eq $_ } @$skip_methods;
        if ($i->{operator}) {
            my $name2 = $name;
            if ($name2 =~ /^operator\s(.+)$/) {
                # operator int => operator_int
                $i->{return} = $1;
                $name2 =~ s/\s+/_/go;
                $name2 =~ s/\*/ptr/go;
                $name2 =~ s/\&/ref/go;
            }
            else {
                my ( $op ) = $name2 =~ /^operator(.+)$/o;
                if (exists $OPERATOR_MAP{$op}) {
                    $name2 = 'operator_'. $OPERATOR_MAP{$op};
                }
                else {
                    print STDERR "no operator op match: operator$op\n";
                }
            }
            $i->{name2} = $name2;
        }
        $i->{parameters} = exists $i->{PARAMETER} ?
          delete $i->{PARAMETER} : [];
        $i->{return}     = delete $i->{RETURN} if exists $i->{RETURN};
        # substitude with full typename for entries in typemap
        if (exists $i->{return}) {
            #print STDERR "return type in $name: ", $i->{return}, "\n";
            $i->{return} = $subst_with_fullname->($i->{return});
            $i->{return} =~ s/^\s*static\b//o;
            unless (exists $typemap->{$i->{return}} and exists $known_primitive_type->{$typemap->{$i->{return}}}) {
                # skip class not in typemap
                unless ($i->{return} eq 'void') {
                    print STDERR "skip method in $meta->{NAME}: $name, $i->{return}\n";
                    next METHOD_LOOP;
                }
            }
        }
        my $param_num = @{$i->{parameters}};
        # handle foo(void)
        if ($param_num == 1 and $i->{parameters}->[0]->{TYPE} eq 'void') {
            splice @{$i->{parameters}}, 0, 1;
            $param_num = 0;
        }
        PARAM_LOOP:
        for (my $j = 0; $j < $param_num; $j++) {
            my $p = $i->{parameters}->[$j];
            $p->{name} = exists $p->{NAME} ? delete $p->{NAME} : "arg$j";
            $p->{type} = delete $p->{TYPE};
            #print STDERR "param type in $name: ", $p->{type}, "\n";
            $p->{type} = $subst_with_fullname->($p->{type});
            if (exists $p->{DEFAULT_VALUE}) {
                $p->{default} = delete $p->{DEFAULT_VALUE};
                my $is_qflags = 0;
                $is_qflags = 1 if exists $typemap->{$p->{type}} and
                  $typemap->{$p->{type}} eq 'T_QFLAGS';
                if ($typemap->{$p->{type}} =~ /OBJ$/o) {
                    my $type2 = $p->{type};
                    $type2 =~ s/^const\s+//o;
                    $type2 =~ s/\s+const$//o;
                    $type2 =~ s/\s*(?:\*|\&)+\s*$//o;
                    $is_qflags = 1 if exists $typemap->{$type2} and
                      $typemap->{$type2} eq 'T_QFLAGS';
                }
                if ($p->{type} eq 'int' and $p->{default} !~ /^(?:-|0x)?\d+$/io) {
                    # non-num enum item
                    if ($p->{default} !~ /\:\:/o) {
                        $p->{default} = $meta->{PERL_NAME}. '::'. $p->{default};
                    }
                }
                elsif (exists $typemap->{$p->{type}} and
                      $typemap->{$p->{type}} eq 'T_ENUM' and
                        $p->{default} !~ /^(?:-|0x)?\d+$/io) {
                    if ($p->{default} !~ /\:\:/o) {
                        # stamp with class name
                        my @type = split /\:\:/, $p->{type};
                        if (@type > 1) {
                            pop @type;
                            $p->{default} = join('::', @type, $p->{default});
                        }
                    }
                }
                elsif ($is_qflags and $p->{default} !~ /^(?:-|0x)?\d+$/io) {
                    ( my $class ) = $p->{type} =~ /QFlags<([^>]+)>/o;
                    $class =~ s/^(.+)\:\:.+$/$1/io;
                    if ($p->{default} =~ /^([^(]+)\((.+)\)$/) {
                        my ( $func, $enums ) = ( $1, $2 );
                        $func = $meta->{PERL_NAME}. '::'. $func if $func !~ /\:\:/io;
                        my @enum = split /\s*\|\s*/, $enums;
                        $enums = join(' | ', map { $class. '::'. $_ } @enum) if @enum and $enum[0] !~ /\:\:/io;
                        $p->{default} = $func. '('. $enums. ')';
                    }
                    elsif ($p->{default} !~ /\:\:/o) {
                        # stamp with class name
                        $p->{default} = join('::', $class, $p->{default});
                    }
                }
                elsif ($p->{default} =~ /^(.+)\(\)$/o) {
                    # maybe subclass
                    # substitude with full class name
                    my $cname = $1;
                    $cname = $subst_with_fullname->($cname);
                    $p->{default} = $cname. '()';
                }
                elsif ($p->{default} =~ /^(.+)\((.+)\)$/o) {
                    my $cname = $1;
                    my $cvalue= $2;
                    $cname = $subst_with_fullname->($cname);
                    # ugly patch to workaround local variable
                    $cvalue= $subst_with_fullname->($cvalue);
                    $cvalue= $meta->{PERL_NAME}. '::'. $cvalue if
                      $cvalue !~ /\:\:/o and $cvalue !~ /^(?:-|0x)?\d+$/o;
                    $p->{default} = $cname. '('. $cvalue .')';
                }
            }
            unless (exists $typemap->{$p->{type}} and exists $known_primitive_type->{$typemap->{$p->{type}}}) {
                # skip class not in typemap
                print STDERR "skip method in $meta->{NAME}: $name, $p->{type}\n";
                next METHOD_LOOP;
            }
            elsif ($p->{type} eq '...') {
                # FIXME: skip va_list
                print STDERR "skip va_list method: $name, $p->{type}\n";
                next METHOD_LOOP;
            }
            # workaround class without default constructor
            # patch QBool to QBool &
            if (grep { $p->{type} eq $_ } @{$mod_conf->{t_object_to_t_refobj}}) {
                $p->{type} = $p->{type}. ' &';
            }
        }
        push @{$pub_methods_by_name->{$name}}, $i;
    }
    # map method with default param value
    # foo(int, int = 0, int = 0)
    # into:
    # foo(int, int, 0  )
    # foo(int, int, int)
    # foo(int, 0  , 0)
    # foo(int, int, 0)
    my $cb_clone_method = sub {
        my ( $method, ) = @_;

        my $clone = {};
        $clone->{parameters} = [];
        foreach my $k (keys %$method) {
            if ($k eq 'parameters') {
                for (my $i = 0; $i < @{$method->{parameters}}; $i++) {
                    foreach my $p (keys %{$method->{parameters}->[$i]}) {
                        $clone->{parameters}->[$i]->{$p} =
                          $method->{parameters}->[$i]->{$p};
    }
                }
            }
            else {
                $clone->{$k} = $method->{$k};
            }
        }
        return $clone;
    };
    foreach my $name (keys %$pub_methods_by_name) {
        my $new_methods = [];

        foreach my $method (@{$pub_methods_by_name->{$name}}) {
            for (my $i = $#{$method->{parameters}}; $i >= 0; $i--) {
                my $p = $method->{parameters}->[$i];
                if (exists $p->{default}) {
                    my $clone = $cb_clone_method->($method);
                    for (my $j = $i; $j >= 0; $j--) {
                        delete $clone->{parameters}->[$j]->{default} if
                          exists $clone->{parameters}->[$j]->{default};
                    }
                    push @$new_methods, $clone;
                }
            }
            push @$new_methods, $method;
        }
        $pub_methods_by_name->{$name} = [ sort {
            scalar(@{$a->{parameters}}) <=> scalar(@{$b->{parameters}})
        } @$new_methods ];
    }

    # generate xs file from template
    # workaround a bug in ttk when a key of hash is 'keys'
    # it gets wrong
    my $mem_methods = [];
    ( my $cname = $meta->{NAME} ) =~ s/^[^<]+:://gio;
    foreach my $m (sort keys %$pub_methods_by_name) {
        next if $m eq $cname;
        next if $m eq '~'. $cname;
        push @$mem_methods, $m;
    }
    my $abstract = 0;
    # check abstract property
    if (exists $meta->{PROPERTY} and grep { $_ eq 'abstract' } @{$meta->{PROPERTY}}) {
        $abstract = 1;
    }
    $abstract = 1 if exists $abstract_class->{$meta->{NAME}};

    #use Data::Dumper;
    #print Data::Dumper::Dumper($pub_methods_by_name);
    my $var = {
        my_name             => $meta->{PERL_NAME},
        my_cclass           => $meta->{NAME},
        my_type             => $meta->{type},
        my_module           => $meta->{MODULE},
        my_package          => $packagemap->{$meta->{NAME}},
        my_file             => $meta->{FILE},
        my_methods          => $mem_methods,
        my_methods_by_name  => $pub_methods_by_name,
        my_enums            => $enums,
        my_typemap          => $typemap,
        my_typemap_template => $typemap_template,
        my_packagemap       => $packagemap,
        my_enummap          => $enummap,
        my_abstract         => $abstract,
        my_has_operator_new => $has_operator_new,
    };
    $template->process('xscode.tt2', $var, \$out) or
      croak $template->error;
    $out .= "\n";
    return $out;
}

sub main {
    my $mod_conf_file   = '';
    my $template_dir    = '';
    my @typemap_files   = ();
    my @packagemap_files= ();
    my $enummap_file    = '';
    my $def_typedef_file= '';
    my $xs_file         = '';
    my $out             = '';
    GetOptions(
        'conf=s'       => \$mod_conf_file,
        'template=s'   => \$template_dir,
        'typemap=s'    => \@typemap_files,
        'packagemap=s' => \@packagemap_files,
        'enummap=s'    => \$enummap_file,
        'default_typedef=s'=> \$def_typedef_file,
        'o|outoput=s'  => \$xs_file,
    );
    usage() unless @ARGV;

    my %f = ();
    foreach my $p (@ARGV) {
        my $f = (split /\//, $p)[-1];
        my @f = split /\./, $f;
        shift @f;
        my $k = join(".", @f);
        $f{$k} = $p;
    }

    croak "no module.conf found" if !-f $mod_conf_file;
    my @path = File::Spec::->splitpath($mod_conf_file);
    pop @path;
    my $f_class_virtual = File::Spec::->catpath(@path, 'class.virtual');
    my %abstract_class = ();
    if (-f $f_class_virtual) {
        open my $F, $f_class_virtual or croak "cannot open file to read: $!";
        while (<$F>) {
            next if /^\s*\#/io;
            chomp;
            $abstract_class{$_}++;
        }
        close $F;
    }
    my %known_primitive_type = ();
    foreach my $f (qw/typemap.tt2 typemap2.tt2/) {
        croak "template file not found: $f" if !-f File::Spec::->catfile($template_dir, $f);
        my $known = get_known_primitive_types(File::Spec::->catfile($template_dir, $f));
        foreach my $t (keys %$known) {
            $known_primitive_type{$t}++;
        }
    }
    #croak "no packagemap file found" if !-f $packagemap_file;
    croak "no default typedef file found" if !-f $def_typedef_file;
    croak "no enummap file found" if !-f $enummap_file;
    my $mod_conf    = load_yaml($mod_conf_file);
    my $def_typedef = load_yaml($def_typedef_file);
    # open source files
    # class name, mod name, class hierarchy
    croak "no meta file found for $xs_file" unless $f{meta};
    my $meta    = load_yaml($f{meta});
    # if ($meta->{TYPE} !~ /^(?:class|struct)$/o) {
    #     print STDERR "skip $f{meta}, not a class or struct\n";
    #     goto WRITE_FILE;
    # }

    # public methods
    #carp "no public file found for $xs_file" unless grep { /public$/ } keys %f;
    my $publics = [];
    foreach my $k (grep { /public$/ } keys %f) {
        my $methods = load_yaml($f{$k});
        push @$publics, @$methods;
    }
    my $enums   = exists $f{enum} ? load_yaml($f{enum}) : [];
    if (@$publics == 0 and @$enums == 0) {
        print STDERR "skip $f{meta}, no public method or enum\n";
        goto WRITE_FILE;
    }
    # class localtype
    my $localtype = exists $f{typemap} ? load_yaml($f{typemap}) : {};
    # draw simple equivalents
    foreach my $k (keys %$localtype) {
        my $v = $localtype->{$k};
        if ($k =~ /^const\s+/o) {
            $k =~ s///o;
            $v =~ s///o;
            $localtype->{$k} = $v;
        }
        else {
            $localtype->{'const '. $k} = 'const '. $v;
            if ($k =~ /\s+&$/o) {
                $k =~ s///o;
                $v =~ s///o;
                $localtype->{$k} = $v;
            }
            else {
                $localtype->{$k. ' &'} = $v. ' &';
            }
        }
        if ($k =~ /\s+&$/o) {
            $k =~ s///o;
            $v =~ s///o;
            $localtype->{$k} = $v;
        }
        else {
            $localtype->{$k. ' &'} = $v. ' &';
        }
    }
    # typedef info
    my $typedef = exists $f{typedef} ? load_yaml($f{typedef}) : {};
    # global typemap
    my $typemap = {};
    my $typemap_template = {};
    foreach my $f (@typemap_files) {
        # open my $F, $f or croak "cannot open file to read: $!";
        # while (<$F>) {
        #     next if /^\s*#/o;
        #     last if /^(?:INPUT|OUTPUT)$/o;
        #     chomp;
        #     next if !$_;
        #     my ( $k, $v ) = split /(?: {2,}|\t+)/, $_, 2;
        #     $typemap->{$k} = $v;
        # }
        my $map = load_yaml($f);
        foreach my $k (keys %$map) {
            $typemap->{$k} = $map->{$k};
        }
        my $f2 = $f. '_template';
        if (-f $f2) {
            $map = load_yaml($f2);
            foreach my $i (@$map) {
                $typemap_template->{$i->{ctype}} = $i;
            }
        }
    }
    # add hidden typemap (for function pointer and enum)
    # in class typedef file
    foreach my $t (keys %$typedef) {
        if ($t =~ /^T_FPOINTER_/o) {
            $typemap->{$t} = 'T_FPOINTER';
        }
        elsif ($typedef->{$t} =~ /^T_FPOINTER_/o) {
            $typemap->{$typedef->{$t}} = 'T_FPOINTER';
        }
    }
    foreach my $t (keys %$def_typedef) {
        if ($t =~ /^T_FPOINTER_/o) {
            $typemap->{$t} = 'T_FPOINTER';
        }
        elsif ($def_typedef->{$t} =~ /^T_FPOINTER_/o) {
            $typemap->{$def_typedef->{$t}} = 'T_FPOINTER';
        }
    }
    # global packagemap
    my $packagemap = {};
    foreach my $f (@packagemap_files) {
        my $map = load_yaml($f);
        foreach my $k (keys %$map) {
            $packagemap->{$k} = $map->{$k};
        }
    }
    # enum map
    my $enummap    = load_yaml($enummap_file);

    my %public_by_name = ();
    foreach my $i (@$publics) {
        $public_by_name{$i->{NAME}}++;
    }
    my $template = Template::->new({
        INCLUDE_PATH => $template_dir,
        INTERPOLATE  => 0,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 0,
        TRIM         => 1,
        EVAL_PERL    => 1,
        #STRICT       => 1,
    });
    my $subst_with_fullname = sub {
        my ( $type, ) = @_;

        # translate local typedef to full class name
        if (exists $localtype->{$type} and $type !~ /^T_(?:FPOINTER|ARRAY)_/o) {
            $type = $localtype->{$type};
        }
        foreach my $t (keys %$def_typedef) {
            if ($def_typedef->{$t} =~ /^T_(?:FPOINTER|ARRAY)_/o) {
                $type =~ s/(?<!\:)\b\Q$t\E\b/$def_typedef->{$t}/ge;
            }
        }
        return $type;
    };

    $out .= create_xs_code(
        mod_conf             => $mod_conf,
        meta                 => $meta,
        publics              => $publics,
        typemap              => $typemap,
        typemap_template     => $typemap_template,
        packagemap           => $packagemap,
        enums                => $enums,
        enummap              => $enummap,
        known_primitive_type => \%known_primitive_type,
        abstract_class       => \%abstract_class,
        template             => $template,
        #localtype            => $localtype,
        #def_typedef          => $def_typedef,
        subst_with_fullname  => $subst_with_fullname,
    );

    # inline parent (template) class methods
    my @dir = File::Spec::->splitpath($f{meta});
    pop @dir;
    my @parent = exists $meta->{ISA} ? @{$meta->{ISA}} : ();
    while (@parent) {
        my $i = pop @parent;
        next if $i->{RELATIONSHIP} ne 'public';
        my $name = $i->{NAME};
        $name = $subst_with_fullname->($name);
        my $cname = $name;
        ( my $n = $name ) =~ s/\:\:/__/go;
        if (exists $typemap_template->{$name}) {
            $name = $typemap_template->{$name}->{name};
            ( $n = $name ) =~ s/\:\:/__/go;
            if (-f "$template_dir/custom/$n.tt2") {
                my $out2 = '';
                $template->process("custom/$n.tt2", $typemap_template->{$i->{NAME}}, \$out2) or
                  croak $template->error;
                my $publics2 = Load($out2);
                # skip constructor/destructor
                $publics2 = [ grep { $_->{NAME} !~ /^(?:~)?\Q$name\E</o } @$publics2 ];
                $out2 = create_xs_code(
                    mod_conf             => $mod_conf,
                    meta                 => $meta,
                    # skip method implemented by child class
                    publics              => [ grep { !exists $public_by_name{$_->{NAME}} } @$publics2 ],
                    typemap              => $typemap,
                    typemap_template     => $typemap_template,
                    packagemap           => $packagemap,
                    enums                => $enums,
                    enummap              => $enummap,
                    known_primitive_type => \%known_primitive_type,
                    abstract_class       => \%abstract_class,
                    template             => $template,
                    #localtype            => $localtype,
                    #def_typedef          => $def_typedef,
                    subst_with_fullname  => $subst_with_fullname,
                );
                # replace parent template class name with class own name
                #$out2 =~ s/\Q$cname\E/$meta->{NAME}/ge if $cname =~ /</io;
                $out .= $out2;
            }
        }
        else {
            # FIXME: load custom function.public file
        }
        # FIXME: only process direct parent
        next;
        # skip template
        next if $n =~ /</io;
        my $f = File::Spec::->catpath(@dir, $n. '.meta');
        if (-f $f) {
            my $j = load_yaml($f);
            push @parent, @{$j->{ISA}} if exists $j->{ISA};
        }
    }
    # work around compiler problem on nested template class
    # '>>' to '> >'
    # given the cpp cout '>>' operator never used anywhere in the
    # code
    $out =~ s/(?<!operator)>>/> >/go;

WRITE_FILE:
    if ($xs_file) {
        open my $F, '>', $xs_file or
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

Copyright (C) 2007 - 2012 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
