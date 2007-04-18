#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_RDONLY O_WRONLY O_TRUNC O_CREAT);
use YAML qw(Dump Load);

=head1 DESCIPTION

Format production from Parse::QTEDI into more binding-make-specific
look. This will both strip unrelevant entry and renew the structure
of other interested entries.

B<NOTE>: All new hash keys inserted here will be uppercase to
differentiate with QTEDI output, except meta field such as 'subtype'. 

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <qtedi_production.yaml> [<output_file>]
EOU
    exit 1;
}

=head1 ELEMENTS

Format functions.

=cut

=over

=item $FUNCTION_PROPERTIES

Keep all known C++ function and QT-specific property keywords.

Function format will firstly filter out them from prototype line.

B<NOTE>: Some properties are stored inside 'PROPERTY' field array for
futher reference.

B<NOTE>: Q_DECL_EXPORT == __attribute((visibility(default)))__ in
gcc. 

=back

=cut

################ DICTIONARY ################
# property storage flag
sub KEEP()    { 1 }

# QT-specific
my $QT_PROPERTIES = {
    Q_TESTLIB_EXPORT                    => 0,
    Q_DECL_EXPORT                       => KEEP,
    Q_DBUS_EXPORT                       => 0,
};

# KDE-specific
my $KDE_PROPERTIES = {
};

# function-specific
my $FUNCTION_PROPERTIES = {
    # C++ standard
    explicit                            => 0,
    implicit                            => 0,
    virtual                             => KEEP,
    inline                              => 0,
    static                              => KEEP,
    friend                              => KEEP,
    # const belongs to return type
    #const                               => KEEP, 
    %$QT_PROPERTIES, 
    %$KDE_PROPERTIES, 
};

# class/struct/union-specific
my $CLASS_PROPERTIES =  { 
    # C++ standard
    inline                              => 0,
    static                              => KEEP,
    friend                              => KEEP,
    mutable                             => 0,
    %$QT_PROPERTIES,
    %$KDE_PROPERTIES,
};

#enum-specific
my $ENUM_PROPERTIES = $FUNCTION_PROPERTIES;

#namespace-specific
my $NAMESPACE_PROPERTIES = $CLASS_PROPERTIES;

################ FORMAT UNIT ################

=over

=item __format_macro

Keep Q_OBJECT and Q_PROPERTY for further consideration.

Each property field inside a Q_PROPERTY will be stored as a new
 key/value pair.

  # spec of Q_PROPERTY

  ---
  name : [from_QTEDI]
  type : macro
  NAME : [name]
  TYPE : [type]
  READ : [read function]
  WRITE: [write function]
  ...

=back

=cut

sub __format_macro {
    my $entry = shift;
    
    # keep Q_OBJECT Q_PROPERTY
    if ($entry->{name} eq 'Q_OBJECT') {
        delete $entry->{subtype};
        return 1;
    }
    elsif ($entry->{name} eq 'Q_PROPERTY') {
        my @values = split / /, $entry->{values};
        $entry->{TYPE} = shift @values;
        $entry->{NAME} = shift @values;
        while (@values) {
            my $k = shift @values;
            my $v = shift @values;
            $entry->{$k} = $v;
        }
        delete $entry->{subtype};
        delete $entry->{values};
        return 1;
    }
    else {
        return 0;
    }
}

sub __format_class_or_struct {
    my $entry = shift;
    my $type  = shift;
    # $type == 0 => class
    # $type == 1 => struct
    # by default class
    $type = 0 unless defined $type;
    
    # format name and property
    if ($entry->{name}) {
        my @values = split /\s+/, $entry->{name};
        my $cname = pop @values;
        foreach my $v (@values) {
            if (exists $CLASS_PROPERTIES->{$v} and 
                  $CLASS_PROPERTIES->{$v} & KEEP) {
                push @{$entry->{property}}, $v;
            }
        }
        $entry->{NAME} = $cname;
    }
    foreach my $p (@{$entry->{property}}) {
        $p =~ s/\s+$//o;
        push @{$entry->{PROPERTY}}, $p;
    }
    delete $entry->{name};
    delete $entry->{property};
    # format inheritance line
    if (exists $entry->{inheritance} and $entry->{inheritance}) {
        my @isa = split /\s*,\s*/, $entry->{inheritance};
        foreach my $l (@isa) {
            my ( $r, $n ) = split /\s+/, $l;
            push @{$entry->{ISA}}, { 
                NAME => $n, RELATIONSHIP => $r, };
        }
        delete $entry->{inheritance};
    }
    # format variable
    if (exists $entry->{variable}) {
        my @variable = split /\s*,\s*/, $entry->{variable};
        foreach my $v (@variable) {
            $v =~ s/\s+$//io;
            push @{$entry->{VARIABLE}}, $v;
        }
        delete $entry->{variable};
    }
    # process body
    # strip private part
    if (exists $entry->{body}) {
        if ($type == 0) {
            # class
            $entry->{BODY} = 
              _format_class_body($entry->{body});
        }
        else {
            # struct
            $entry->{BODY} = 
              _format_struct_body($entry->{body});
        }
        delete $entry->{body};
    }
    return 1;
}

=over

=item __format_class

Extract class name string and store as new field. Recursively process
 class body, strip private part.

Format inheritance line if has.

  # spec 
  
  ---
  type     : class
  PROPERTY : 
     - [class property1]
     ...
  NAME     : [name]
  ISA      : 
     - NAME         : [parent class name]
       RELATIONSHIP : public/private/protected
     ...
  BODY     : 
     ...
  VARIABLE : 
     - [variable1]
     ...

=back

=cut

sub __format_class {
    return __format_class_or_struct($_[0], 0);
}

=over

=item __format_struct

Similar as __format_class.

B<NOTE>: As defined in C++, top entries not covered by any
public/private/protected keyword will be treated private.

See __format_class above regarding output spec.

=back

=cut

sub __format_struct {
    return __format_class_or_struct($_[0], 1);
}

=over

=item __format_union

Similar as __format_struct.

See __format_class above regarding output spec.

=back

=cut

sub __format_union {
    # FIXME: how to deal with union
    return __format_class_or_struct($_[0], 1);
}

=over

=item __format_function

Format a function entry. Extract return type, function name and all
parameters from function entry from QTEDI.

  # spec 
  
  ---
  type      : function
  subtype   : 1/0 [is operator or not]
  PROPERTY  : 
     - [function property1]
     ...
  NAME      : [name]
  RETURN    : [return type]
  PARAMETER : 
     - TYPE          : [param1 type]
                       [NOTE: could be '...' in ansi]
       NAME          : [param1 name]
       DEFAULT_VALUE : [param1 default value]
     ...

=back

=cut

sub __format_function {
    my $entry = shift;
    
    #print STDERR $entry->{name}, "\n";
    my $fname_with_prefix = $entry->{name};
    # filter out keywords from name
    my @fvalues = split /\s*\b\s*/, $fname_with_prefix;
    my $properties = [];
    my @fname        = ();
    my @freturn_type = ();
    # get function name
    # pre-scan for operator function
    my $is_operator_function = 0;
    FN_OPERATOR_LOOP:
    for (my $i = $#fvalues; $i >= 0; $i--) {
        if ($fvalues[$i] eq 'operator') {
            # store as function name starting by operator keyword
            @fname = splice @fvalues, $i;
            $is_operator_function = 1;
            last FN_OPERATOR_LOOP;
        }
    }
    unshift @fname, pop @fvalues unless $is_operator_function;
    FN_LOOP:
    for (my $i = $#fvalues; $i >= 0; ) {
        if ($fvalues[$i] eq '::') {
            # namespace
            unshift @fname, pop @fvalues;
            unshift @fname, pop @fvalues;
            $i -= 2;
        }
        elsif ($fvalues[$i] eq '~') {
            # C++ destructor
            unshift @fname, pop @fvalues;
            $i--;
        }
        elsif ($fvalues[$i] eq '::~') {
            # destructor within namespace ;-(
            unshift @fname, pop @fvalues;
            unshift @fname, pop @fvalues;
            $i -= 2;
        }
        else {
            last FN_LOOP;
        }
    }
    # get return type
    # filter out properties 
    foreach my $v (@fvalues) {
        if (exists $FUNCTION_PROPERTIES->{$v}) {
            if ($FUNCTION_PROPERTIES->{$v} & KEEP) {
                unshift @$properties, $v;
            }
        }
        else {
            push @freturn_type, $v;
        }
    }
    if (exists $entry->{property}) {
        foreach my $p (@{$entry->{property}}) {
            if (exists $FUNCTION_PROPERTIES->{$p} and 
                  $FUNCTION_PROPERTIES->{$p} & KEEP) {
                unshift @$properties, $p;
            }
        }
    }
    # format return type
    my $return_type;
    if (@freturn_type) {
        $return_type = shift @freturn_type;
        for (my $i = 0; $i <= $#freturn_type; ) {
            if ($freturn_type[$i] eq '::') {
                $return_type .= $freturn_type[$i]. $freturn_type[$i+1];
                $i += 2;
            } 
            elsif ($freturn_type[$i] eq '<') {
                $return_type .= $freturn_type[$i];
                $i++;
            }
            else {
                $return_type .= ' '. $freturn_type[$i];
                $i++;
            }
        }
    }
    else {
        $return_type = '';
    }
    # format params
    my $parameters = [];
    PARAMETER_MAIN_LOOP: 
    foreach my $p (@{$entry->{parameter}}) {
        next PARAMETER_MAIN_LOOP if 
          $p->{subtype} eq 'simple' and $p->{name} eq '';
        
        my $pname_with_type = $p->{name};
        my $psubtype        = $p->{subtype};
        my $pdefault_value  = 
          exists $p->{default} ? $p->{default} : '';
        $pdefault_value =~ s/\s+$//o;
        my ( $pname, $ptype );
        
        if ($psubtype eq 'fpointer') {
            # FIXME: better differentiate the type of function pointer
            my $_FP_TYPE = 'FUNCTION_POINTER';
            $ptype = $_FP_TYPE;
            # TODO: should keep all interface info here ???
            # FIXME: better presenting special fpointer
            if (ref $pname_with_type eq 'HASH') {
                # okay, probably a function pointer
                # which returns another function pointer
                ( $pname = $pname_with_type->{name} ) =~
                  s/^\s*\*//gio;
            }
            else {
                ( $pname = $pname_with_type ) =~ s/^\s*\*//gio;
            }
        }
        else {
            # simple && template
            # split param name [optional] and param type
            my @pvalues = 
              split /\s*(?<!::)\b(?!::)\s*/, $pname_with_type;
            my @pname = ();
            my @ptype = ();
            if (@pvalues == 1) {
                # only one entry, be of param type
                # noop
            }
            # \w may be different on different systems
            # here strictly as an 'old' word
            elsif ($pvalues[$#pvalues] =~ m/^[a-z_A-Z_0-9_\_]+$/o) {
                # process param name
                unshift @pname, pop @pvalues;
                FP_LOOP:
                for (my $i = $#pvalues; $i >= 0; ) {
                    if ($pvalues[$i] eq '::') {
                        # namespace
                        unshift @pname, pop @pvalues;
                        unshift @pname, pop @pvalues;
                        $i -= 2;
                    } 
                    else {
                        last FP_LOOP;
                    }
                }
            }
            # left is type
            @ptype = @pvalues;
            # format param name
            $pname = @pname ? join('', @pname) : '';
            # format param type
            $ptype = '';
            if (@ptype) {
                $ptype = shift @ptype;
                for (my $i = 0; $i <= $#ptype; ) {
                    if ($ptype[$i] eq '::') {
                        $ptype .= $ptype[$i]. $ptype[$i+1];
                        $i += 2;
                    } 
                    else {
                        $ptype .= ' '. $ptype[$i];
                        $i++;
                    }
                }
            }
            $ptype =~ s/\s+$//o;
        }
        # store param unit
        my $p = { TYPE => $ptype };
        $p->{NAME} = $pname if $pname;
        $p->{DEFAULT_VALUE} = $pdefault_value if $pdefault_value;
        push @$parameters, $p;
    }
    
    # format function name
    my $fname = '';
    if ($is_operator_function) {
        my $i = 0;
        FN_FORMAT_LOOP:
        for (; $i < @fname; $i++) {
            $fname .= $fname[$i];
            last FN_FORMAT_LOOP if $fname[$i] eq 'operator';
        }
        if ($fname[++$i] =~ m/^[a-z_A-Z_0-9_\_]+$/o) {
            # type cast operator such as 
            # operator int
            $fname .= ' '. $fname[$i++];
        }
        else {
            # operator+ and like
            $fname .= $fname[$i++];
        }
        for (; $i < @fname; $i++) {
            if ($fname[$i] eq '<') {
                # template type
                $fname .= $fname[$i];
            }
            else {
                $fname .= ' '. $fname[$i];
            }
        }
    }
    else {
        $fname = join('', @fname);
    }
    # store
    $entry->{NAME}      = $fname;
    # meta info field
    $entry->{subtype}   = $is_operator_function ? 1 : 0;
    $entry->{RETURN}    = $return_type if $return_type;
    $entry->{PROPERTY}  = $properties if @$properties;
    $entry->{PARAMETER} = $parameters if @$parameters;
    delete $entry->{name};
    delete $entry->{parameter};
    delete $entry->{property};
    return 1;
}

=over

=item __format_enum

Format enum, normalize name, property and enum value entries.

  # spec 
  
  ---
  type     : enum
  NAME     : [name]
  PROPERTY : 
     - [enum property1]
     ...
  VALUE    : 
     - [enum value1]
     ...
  VARIABLE : 
     - [variable1]
     ...

=back

=cut

sub __format_enum {
    my $entry = shift;
    
    # format name and property
    if ($entry->{name}) {
        my @values = split /\s+/, $entry->{name};
        my $ename = pop @values;
        foreach my $v (@values) {
            if (exists $ENUM_PROPERTIES->{$v} and 
                  $ENUM_PROPERTIES->{$v} & KEEP) {
                push @{$entry->{property}}, $v;
            }
        }
        $entry->{NAME} = $ename;
    }
    foreach my $p (@{$entry->{property}}) {
        $p =~ s/\s+$//o;
        push @{$entry->{PROPERTY}}, $p;
    }
    delete $entry->{name};
    delete $entry->{property};
    # normalize value entries
    foreach my $v (@{$entry->{value}}) {
        $v =~ s/\s+$//o;
    }
    if (@{$entry->{value}}) {
        $entry->{VALUE} = $entry->{value};
        delete $entry->{value};
    }
    # format variable
    if (exists $entry->{variable}) {
        my @variable = split /\s*,\s*/, $entry->{variable};
        foreach my $v (@variable) {
            $v =~ s/\s+$//io;
            push @{$entry->{VARIABLE}}, $v;
        }
    }
    return 1;
}

=over

=item __format_accessibility

Format accessibility, normalize value entries.

B<NOTE>: private type should not appear here since being stripped. 

  # spec 
  
  ---
  type     : accessibility
  VALUE    : 
     - [accessibility keyword1]
     ...

=back

=cut

sub __format_accessibility {
    my $entry = shift;
    
    # normalize value entries
    foreach my $v (@{$entry->{value}}) {
        $v =~ s/\s+$//o;
    }
    if (@{$entry->{value}}) {
        $entry->{VALUE} = $entry->{value};
        delete $entry->{value};
    }
    return 1;
}

=over

=item __format_typedef

Format typedef, normalize value entry.

Value entry could be of type:

  1. typedef simple type C<< typedef A B; >>
  2. typedef (anonymous) class/struct/enum/union C<< typdef enum A { } B; >> 
  3. typedef function pointer C<< typedef void (*P)(int, uint); >>
  4. typedef an array C<< typedef unsigned char Digest[16]; >> 

  # spec 
  
  ---
  type    : typedef
  subtype : class/struct/enum/union/fpointer/simple
  FROM    : [from type name for simple typedef    ]
            [a hashref for class/struct/enum/union]
            ['FUNCTION_POINTER' for fpointer      ]
  TO      : [to type name]

=back

=cut

sub __format_typedef {
    my $entry = shift;
    
    # extract body entry
    if (ref $entry->{body} eq 'HASH') {
        $entry->{subtype} = $entry->{body}->{type};
        if ($entry->{subtype} eq 'fpointer') {
            # fpointer
            # keep typedefed name
            # FIXME: should keep hash entry ???
            $entry->{FROM} = 'FUNCTION_POINTER';
            if (ref $entry->{body}->{name} eq 'HASH') {
                # okay, probably a function pointer
                # which returns another function pointer
                ( $entry->{TO} = $entry->{body}->{name}->{name} ) =~
                  s/^\s*\*//gio;
            }
            else {
                ( $entry->{TO} = $entry->{body}->{name} ) =~ 
                  s/^\s*\*//gio;
            }
        }
        else {
            # other container type
            my $temp = [];
            _format_primitive_loop($entry->{body}, $temp);
            my $body = $temp->[0];
            $entry->{FROM} = $body->{NAME} if exists $body->{NAME};
            # $body->{VARIABLE} should exist this case
            # and has only one entry
            # or else something is wrong
            $entry->{TO}   = $body->{VARIABLE}->[0];
            # pointer/reference digit be moved into FROM
            if ($entry->{TO} =~ s/^\s*((?:\*|\&))//io) {
                $entry->{FROM} .= ' '. $1;
            }
        }
    }
    else {
        # simple
        $entry->{subtype} = 'simple';
        if ($entry->{body} =~ m/^(.*)\b(\w+)((?:\[\d+\])+)$/io) {
            # array typedef
            $entry->{TO}   = $2;
            $entry->{FROM} = $1. $3;
        }
        else {
            # other simple typedef
            # NOTE: QValueList < KConfigSkeletonItem * >List
            # strip tail space
            $entry->{body} =~ s/\s+$//io;
            ( $entry->{FROM}, $entry->{TO} ) = 
              $entry->{body} =~ m/(.*)\s+([a-z_A-Z_0-9_\__\*_\&\>]+)$/io;
            # pointer/reference digit be moved into FROM
            if ($entry->{TO} =~ s/^\s*((?:\*|\&|\>))//io) {
                $entry->{FROM} .= ' '. $1;
            }
        }
    }
    delete $entry->{body};
    return 1;
}

=over

=item __format_extern

Format extern type body.

  # spec 
  
  ---
  type    : extern
  subtype : C/function/expression/class/struct/union/enum
  BODY    : 
     ...

B<NOTE>: For subtype C, there will be more than one entry in BODY
field array. For others, just one.

=back

=cut

sub __format_extern {
    my $entry = shift;
    my $rc    = 0;
    
    # keep function/enum/class/struct/C
    if ($entry->{subtype} eq 'function') {
        __format_function($entry->{body});
        $rc = 1;
    }
    elsif ($entry->{subtype} eq 'enum') {
        __format_enum($entry->{body});
        $rc = 1;
    }
    elsif ($entry->{subtype} eq 'class') {
        if ($entry->{body}->{type} eq 'class') {
            $entry->{body} = __format_class($entry->{body});
            $rc = 1;
        }
        elsif ($entry->{body}->{type} eq 'struct') {
            $entry->{body} = __format_struct($entry->{body});
            $rc = 1;
        }
    }
    elsif ($entry->{subtype} eq 'C') {
        $entry->{body} = _format($entry->{body});
        $rc = 1;
    }
    # store
    if ($rc) {
        if ($entry->{subtype} eq 'C') {
            $entry->{BODY} = $entry->{body};
        }
        else {
            push @{$entry->{BODY}}, $entry->{body};
        }
        delete $entry->{body};
    }
    return $rc;
}

=over

=item __format_namespace

Format namespace code block. Normalize name and recursively format
body entries. 

  # spec 
  
  ---
  type     : namespace
  NAME     : [namespace name]
  PROPERTY : 
     - [property1]
     ...
  BODY     : 
     ...

=back

=cut

sub __format_namespace {
    my $entry = shift;
    
    # format name and property
    if ($entry->{name}) {
        my @values = split /\s+/, $entry->{name};
        my $nname = pop @values;
        foreach my $v (@values) {
            if (exists $NAMESPACE_PROPERTIES->{$v} and 
                  $NAMESPACE_PROPERTIES->{$v} & KEEP) {
                push @{$entry->{property}}, $v;
            }
        }
        $entry->{NAME} = $nname;
    }
    foreach my $p (@{$entry->{property}}) {
        $p =~ s/\s+$//o;
        push @{$entry->{PROPERTY}}, $p;
    }
    delete $entry->{name};
    delete $entry->{property};
    # format body
    $entry->{body} = _format($entry->{body}) if 
      exists $entry->{body};
    return 1;
}

=over

=item __format_expression

Format expression.

B<NOTE>: currently expression is stripped. 

  # spec 
  
  ---
  type  : expression
  value : [expression line]

=back

=cut

sub __format_expression {
    # FIXME: how to use such information
    #        for now just skip
    0;
}

################ FORMAT FUNCTION ################
sub _format_primitive_loop {
    my $entry             = shift;
    my $formatted_entries = shift;

    #use Data::Dumper;
    #print Dump($entry), "\n";
    if ($entry->{type} eq 'macro') {
        __format_macro($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'class') {
        __format_class($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'struct') {
        __format_struct($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'union') {
        __format_union($entry) and 
          push @$formatted_entries, $entry;
    }
    elsif ($entry->{type} eq 'extern') {
        __format_extern($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'namespace') {
        __format_namespace($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'function') {
        __format_function($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'enum') {
        __format_enum($entry) and 
          push @$formatted_entries, $entry;
    } 
#    elsif ($entry->{type} eq 'accessibility') {
#        __format_accessibility($entry) and 
#          push @$formatted_entries, $entry;
#    } 
    elsif ($entry->{type} eq 'typedef') {
        __format_typedef($entry) and 
          push @$formatted_entries, $entry;
    }
}

sub _format {
    my $entries           = shift;
    my $formatted_entries = [];
    
    # strip strategy: comment/expression/template
    foreach my $entry (@$entries) {
        #print STDERR $entry->{type}, "\n";
        _format_primitive_loop($entry, $formatted_entries);
    }
    return $formatted_entries;
}

sub _format_with_accessibility {
    my $entries           = shift;
    my $private           = shift;
    $private = defined $private ? $private : 1;
    my $formatted_entries = [];
    
    # strip strategy: comment/template/expression
    LOOP_BODY:
    foreach my $entry (@$entries) {
        #print STDERR $entry->{type}, "\n";
        if (not $private) {
            if ($entry->{type} eq 'accessibility' and 
                  $entry->{value}->[-1] eq 'private') {
                $private = 1;
                next LOOP_BODY;
            }
            elsif ($entry->{type} eq 'expression') {
                __format_expression($entry) and 
                  push @$formatted_entries, $entry;
            }
            else {
                _format_primitive_loop($entry, $formatted_entries);
            }
        }
        else {
            # private scope
            if ($entry->{type} eq 'accessibility' and 
                  $entry->{value}->[-1] ne 'private') {
                $private = 0;
                __format_accessibility($entry) and 
                  push @$formatted_entries, $entry;
                next LOOP_BODY;
            }
        }
    }
    return $formatted_entries;
}

sub _format_keep_expression {
    my $entries           = shift;
    my $formatted_entries = [];
    
    # strip strategy: comment/template
    foreach my $entry (@$entries) {
        #print STDERR $entry->{type}, "\n";
        if ($entry->{type} eq 'expression') {
            __format_expression($entry) and 
              push @$formatted_entries, $entry;
        }
        else {
            _format_primitive_loop($entry, $formatted_entries);
        }
    }
    return $formatted_entries;
}

sub _format_struct_body {
    # initially public
    _format_with_accessibility($_[0], 0);
}

sub _format_class_body {
    # initially private
    _format_with_accessibility($_[0], 1);
}

################ MAIN ################
sub main {
    usage() unless @ARGV;
    my ( $in, $out ) = @ARGV;
    die "file not found" unless -f $in;
    
    local ( *INPUT );
    open INPUT, '<', $in or die "cannot open file: $!";
    my $cont = do { local $/; <INPUT>; };
    close INPUT;
    my ( $entries ) = Load($cont);
    $cont = Dump(_format($entries));
    
    if (defined $out) {
        local ( *OUTPUT );
        sysopen OUTPUT, $out, O_CREAT|O_WRONLY|O_TRUNC or 
          die "cannot open file to write: $!";
        print OUTPUT $cont;
        close OUTPUT or die "cannot write to file: $!";
    }
    else {
        print STDOUT $cont;
    }
    exit 0;
}

&main;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut
