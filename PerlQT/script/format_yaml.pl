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

=item __format_function

Format a function entry. Extract return type, function name and all
parameters from function prototype line from QTEDI.

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
       NAME          : [param1 name]
       DEFAULT_VALUE : [param1 default value]
     ...

=back

=cut

sub __format_function {
    my $entry = shift;
    
    #print STDERR $entry->{name}, "\n";
    my ( $fname_with_prefix, $fparams ) = 
      $entry->{name} =~ m/^(.*)\((.*)\)\s*$/io;
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
            $i--;
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
    if ($fparams) {
        my @params = split /\s*,\s*/, $fparams;
        foreach my $p (@params) {
            my @parameter = split /\s*=\s*/, $p;
            my $pname_with_type = $parameter[0];
            my $pdefault_value   = @parameter == 2 ? $parameter[1] :
              '';
            $pdefault_value =~ s/\s+$//o;
            # split param name [optional] and param type
            my @pvalues = split /\s*\b\s*/, $pname_with_type;
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
            my $pname = @pname ? join('', @pname) : '';
            # format param type
            my $ptype = '';
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
            # store param unit
            my $p = { TYPE => $ptype };
            $p->{NAME} = $pname if $pname;
            $p->{DEFAULT_VALUE} = $pdefault_value if $pdefault_value;
            push @$parameters, $p;
        }
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
    delete $entry->{fullname};
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

  # spec 
  
  ---
  type    : typedef
  subtype : 1/2/3
  FROM    : [from type name]
  TO      : [to type name]
  EXTRA   : [subtype 2, formatted class/struct/enum/union entry   ] 
            [subtype 3, raw typedef line without leading 'typedef']

=back

=cut

sub __format_typedef {
    my $entry = shift;
    
    # extract value entry
    if (ref $entry->{value} eq 'HASH') {
        # subtype 2
        # container class type
        $entry->{subtype} = 2;
        my $temp = [];
        _format_primitive_loop($entry->{value}, $temp);
        $entry->{EXTRA} = $temp->[0];
        $entry->{FROM} = $entry->{EXTRA}->{NAME} if 
          exists $entry->{EXTRA}->{NAME};
        # $entry->{EXTRA}->{VARIABLE} should exist this case
        # and has only one entry
        # or else something is wrong
        $entry->{TO}   = $entry->{EXTRA}->{VARIABLE}->[0];
    }
    else {
        if ($entry->{value} =~ m/\(/io) {
            # subtype 3
            # function pointer
            $entry->{subtype} = 3;
            # FIXME: function pointer typedef could be more complex 
            #        than something as void (*P)(int)
            #        a classic case is linux signal function
            #        old declaration is something like
            #        void ((*signal(int)))(int)
            #        nowadays it has been simplified by typedef
            my ( $to ) = 
              $entry->{value} =~ m/^(?>[^\(]+)\(\*((?>[^\)]+))\)/io;
            if (defined $to) {
                $entry->{TO} = $to;
            }
            else {
                warn "couldnot extract function pointer type name";
            }
            # for reference
            $entry->{EXTRA} = $entry->{value};
        }
        else {
            # subtype 1
            # simple
            my @values = split /(?<!(?:\<|,))\s+(?!(?:\>|\*\>))/, 
              $entry->{value};
            if (@values == 2) {
                $entry->{FROM} = $values[0];
                $entry->{TO}   = $values[1];
            }
            else {
                warn "couldnot extract simple typedef name";
            }
        }
    }
    delete $entry->{value};
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
            $entry->{body} = _format_class_body($entry->{body});
            $rc = 1;
        }
        elsif ($entry->{body}->{type} eq 'struct') {
            $entry->{body} = _format_struct_body($entry->{body});
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

  # spec 
  
  ---
  type  : expression
  value : [expression line]

=back

=cut

sub __format_expression {
    # FIXME: how to use such information
    #        for now just skip
    return 0;
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
    my $cont;
    {
        local $/;
        $cont = <INPUT>;
    }
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

