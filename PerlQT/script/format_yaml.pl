#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_RDONLY O_WRONLY O_TRUNC O_CREAT);
use YAML qw(Dump Load);

=head1 DESCIPTION

Format production from Parse::QTEDI into more binding-make-specific
look. This will both strip unrelevant entry and renew the structure
of other interested entry.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

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
};

################ FORMAT UNIT ################
sub __format_macro {
    my $entry = shift;
    
    # keep Q_OBJECT Q_PROPERTY
    if ($entry->{name} eq 'Q_OBJECT') {
        delete $entry->{subtype};
    }
    if ($entry->{name} eq 'Q_PROPERTY') {
        my @values = split / /, $entry->{values};
        $entry->{TYPE} = shift @values;
        $entry->{NAME} = shift @values;
        $entry = { %$entry, @values };
        delete $entry->{subtype};
        delete $entry->{values};
    }
}

sub __format_class {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format($entry->{body}) if 
      exists $entry->{body};
}

sub __format_struct {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format_in_struct($entry->{body}) if 
      exists $entry->{body};
}

sub __format_function {
    my $entry = shift;
    
    # FIXME: extract prototype
    my ( $name, $params ) = 
      $entry->{name} =~ m/^((?>[^(]+))\((.*)\)\s*$/io;
    $entry->{name} = $name;
    $entry->{param} = $params;
    delete $entry->{fullname};
}

sub __format_enum {
    my $entry = shift;
    
    # normalize
    $entry->{name} and $entry->{name} =~ s/\s+$//o;
    foreach my $v (@{$entry->{value}}) {
        $v =~ s/\s+$//o;
    }
}

sub __format_accessibility {
    my $entry = shift;
    
    # normalize
    foreach my $v (@{$entry->{value}}) {
        $v =~ s/\s+$//o;
    }
}

sub __format_typedef {
    my $entry = shift;
    
    # FIXME
}

sub __format_extern {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format($entry->{body}) if 
      exists $entry->{body};
}

sub __format_namespace {
    my $entry = shift;
    
    # FIXME: extract name
    $entry->{body} = _format($entry->{body}) if 
      exists $entry->{body};
}

sub __format_expression {
}

################ FORMAT FUNCTION ################
sub _format_primitive_loop {
    my $entry             = shift;
    my $formatted_entries = shift;

    #use Data::Dumper;
    #print Dump($entry), "\n";
    if ($entry->{type} eq 'macro') {
        __format_macro($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'class') {
        __format_class($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'struct') {
        __format_struct($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'extern') {
        __format_extern($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'namespace') {
        __format_namespace($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'function') {
        __format_function($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'enum') {
        __format_enum($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'accessibility') {
        __format_accessibility($entry);
        push @$formatted_entries, $entry;
    } elsif ($entry->{type} eq 'typedef') {
        __format_typedef($entry);
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

sub _format_in_struct {
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
