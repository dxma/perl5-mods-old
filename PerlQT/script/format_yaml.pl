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

sub _format {
    my $entries = shift;
    my $formatted_entries = [];
    
    # strip strategy: comment/expression/template
    foreach my $entry (@$entries) {
        #print STDERR $entry->{type}, "\n";
        if ($entry->{type} eq 'macro') {
            # keep Q_OBJECT Q_PROPERTY
            if ($entry->{name} eq 'Q_OBJECT') {
                delete $entry->{subtype};
                push @$formatted_entries, $entry;
            }
            if ($entry->{name} eq 'Q_PROPERTY') {
                my @values = split / /, $entry->{values};
                $entry->{TYPE} = shift @values;
                $entry->{NAME} = shift @values;
                $entry = { %$entry, @values };
                delete $entry->{subtype};
                delete $entry->{values};
                push @$formatted_entries, $entry;
            }
        }
        elsif ($entry->{type} eq 'class') {
            # FIXME: extract name
            $entry->{body} = _format($entry->{body}) if 
              exists $entry->{body};
            push @$formatted_entries, $entry;
        }
        elsif ($entry->{type} eq 'struct') {
            # FIXME: extract name
            $entry->{body} = _format($entry->{body}) if 
              exists $entry->{body};
            push @$formatted_entries, $entry;
        }
        elsif ($entry->{type} eq 'function') {
            # FIXME: extract prototype
            delete $entry->{fullname};
            push @$formatted_entries, $entry;
        }
        elsif ($entry->{type} eq 'enum') {
            $entry->{name} and $entry->{name} =~ s/\s+$//o;
            # normalize
            foreach my $v (@{$entry->{value}}) {
                $v =~ s/\s+$//o;
            }
            push @$formatted_entries, $entry;
        }
        elsif ($entry->{type} eq 'accessibility') {
            # normalize
            foreach my $v (@{$entry->{value}}) {
                $v =~ s/\s+$//o;
            }
            push @$formatted_entries, $entry;
        }
        elsif ($entry->{type} eq 'typedef') {
            push @$formatted_entries, $entry;
        }
    }
    return $formatted_entries;
}

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
