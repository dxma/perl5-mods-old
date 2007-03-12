#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_RDONLY O_WRONLY O_TRUNC O_CREAT);
use YAML qw(Dump Load);

=head1 DESCIPTION

Format production from Parse::QTEDI into more binding-make-specific
look. This will both strip unrelevant entry and renew the structure
of other interested entry.

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <qtedi_production.yaml> [<output_file>]
EOU
    exit 1;
}

################ DICTIONARY ################
# property storage flag
sub FP_KEEP()    { 1 }
my $FUNCTION_PROPERTIES = {
    # C++ standard
    explicit                            => 0,
    implicit                            => 0,
    virtual                             => FP_KEEP,
    inline                              => 0,
    static                              => FP_KEEP,
    friend                              => FP_KEEP,
    # QT-specific
    Q_TESTLIB_EXPORT                    => 0,
    Q_DECL_EXPORT                       => FP_KEEP,
    Q_DBUS_EXPORT                       => 0,
};

################ FORMAT UNIT ################
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

sub __format_class {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format($entry->{body}) if 
      exists $entry->{body};
    return 1;
}

sub __format_struct {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format_in_struct($entry->{body}) if 
      exists $entry->{body};
    return 1;
}

sub __format_function {
    my $entry = shift;
    
    #print STDERR $entry->{name}, "\n";
    # FIXME: extract prototype
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
            if ($FUNCTION_PROPERTIES->{$v} & FP_KEEP) {
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
    my $fname = shift @fname;
    if ($is_operator_function) {
        my $i = 0;
        FN_FORMAT_LOOP:
        for (; $i < @fname; $i++) {
            $fname .= $fname[$i];
            last FN_FORMAT_LOOP if $fname[$i] eq 'operator';
        }
        # FIXME
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

sub __format_enum {
    my $entry = shift;
    
    # normalize
    $entry->{name} and $entry->{name} =~ s/\s+$//o;
    foreach my $v (@{$entry->{value}}) {
        $v =~ s/\s+$//o;
    }
    return 1;
}

sub __format_accessibility {
    my $entry = shift;
    
    # normalize
    foreach my $v (@{$entry->{value}}) {
        $v =~ s/\s+$//o;
    }
    return 1;
}

sub __format_typedef {
    my $entry = shift;
    
    # FIXME
    return 1;
}

sub __format_extern {
    my $entry = shift;
    
    # keep function/enum/class/C
    # FIXME: extract name
    if ($entry->{subtype} eq 'function') {
        __format_function($entry->{body});
        return 1;
    }
    elsif ($entry->{subtype} eq 'enum') {
        __format_enum($entry->{body});
        return 1;
    }
    elsif ($entry->{subtype} eq 'class') {
        if ($entry->{body}->{type} eq 'class') {
            $entry->{body} = _format($entry->{body});
            return 1;
        }
        elsif ($entry->{body}->{type} eq 'struct') {
            $entry->{body} = _format_in_struct($entry->{body});
            return 1;
        }
        else {
            return 0;
        }
    }
    elsif ($entry->{subtype} eq 'C') {
        # FIXME: keep expression ?
        $entry->{body} = _format_keep_expression($entry->{body});
        return 1;
    }
    else {
        return 0;
    }
}

sub __format_namespace {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format($entry->{body}) if 
      exists $entry->{body};
    return 1;
}

sub __format_expression {
    # FIXME: keep expression
    return 1;
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
    elsif ($entry->{type} eq 'accessibility') {
        __format_accessibility($entry) and 
          push @$formatted_entries, $entry;
    } 
    elsif ($entry->{type} eq 'typedef') {
        __format_typedef($entry) and 
          push @$formatted_entries, $entry;
    }
}

sub _format {
    my $entries = shift;
    my $formatted_entries = [];
    
    # strip strategy: comment/expression/template
    foreach my $entry (@$entries) {
        #print STDERR $entry->{type}, "\n";
        _format_primitive_loop($entry, $formatted_entries);
    }
    return $formatted_entries;
}

sub _format_keep_expression {
    my $entries = shift;
    my $formatted_entries = [];
    
    # strip strategy: comment/template
    foreach my $entry (@$entries) {
        #print STDERR $entry->{type}, "\n";
        _format_primitive_loop($entry, $formatted_entries);
        if ($entry->{type} eq 'expression') {
            __format_expression($entry);
            push @$formatted_entries, $entry;
        }
    }
    return $formatted_entries;
}

sub _format_in_struct {
    &_format_keep_expression;
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

