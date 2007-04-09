#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_WRONLY O_TRUNC O_CREAT :flock);
use YAML;
use File::Spec ();

=head1 DESCIPTION

Group formatted QTEDI production by namespace.

For each namespace there will be files generated as below:

  1. <namespace_name>.typemap
  2. <namespace_name>.enum
  3. <namespace_name>.function.public
  4. <namespace_name>.function.protected
  5. <namespace_name>.signal
  6. <namespace_name>.slot.public
  7. <namespace_name>.slot.protected

B<NOTE>: 'namespace' here, as a generic form, stands for any
full-qualified class/struct/namespace name in C/CXX. 

B<NOTE>: filename length limit is _PC_NAME_MAX on POSIX,
normally this should not be an issue. 

B<NOTE>: a special namespace - std, will hold any entry which doesn't
belong to other namespace. 

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <formatted_qtedi_output.yaml> <output_directory>
EOU
    exit 1;
}

# private consts
sub NAMESPACE_DEFAULT { 'std' }

sub VISIBILITY_PUBLIC { 
    +{ type => 'accessibility', VALUE => [ 'public' ], } 
}

sub VISIBILITY_PRIVATE {
    +{ type => 'accessibility', VALUE => [ 'private' ], }
}

=over

=item write_to_file

A configurable hook to save content into a file. How/where to
create such file and the file name is totally blind for caller. 

B<NOTE>: Currently create the file with a full-qualified
namespace string as its name. 

=back

=cut

sub write_to_file {
    my ( $hcont, $root_dir, @namespace ) = @_;
    
    my $NS_DELIMITER = q(::);
    my $FN_DELIMITER = q(__);
    my $FN_DEFAULT   = q(std);
    die "root directory not found" unless -d $root_dir;
    my $filename;
    if (@namespace) {
        $filename = join($NS_DELIMITER, @namespace);
        $filename =~ s/(?:\Q$NS_DELIMITER\E)+/$FN_DELIMITER/ge;
    }
    else {
        $filename = $FN_DEFAULT;
    }
    $filename = File::Spec::->catfile($root_dir, $filename);
    foreach my $k (keys %$hcont) {
        local ( *OUT );
        sysopen OUT, $filename. '.'. lc($k), O_CREAT|O_WRONLY or 
          die "cannot open file to write: $!";
        until (flock OUT, LOCK_EX) { sleep 3; }
        seek OUT, 0, 2;
        my $cont_dump = Dump($hcont->{$k});
        print OUT $cont_dump;
        close OUT or die "cannot write to file: $!";
    }
}

=over

=item __process_accessibility

Adapt content of @$types accordingly. Invoked by _process.

=back

=cut

sub __process_accessibility {
    my ( $entry, $entries, $namespaces, $types ) = @_;
    
    # update $types, others left untouched
    splice @$types, 0, scalar(@$types);
    foreach my $t (@{$entry->{VALUE}}) {
        if ($t eq 'Q_SIGNALS' or $t eq 'signals') {
            # Q_SIGNALS/signals
            push @$types, 'signal';
        }
        elsif ($t eq 'Q_SLOTS' or $t eq 'slots') {
            # Q_SLOTS/slots
            push @$types, 'slot';
        }
        else {
            # public/private/protected
            push @$types, $t;
        }
    }
}

=over

=item 

Internal use only. Generate a simple typedef entry.

=back

=cut

sub __gen_simple_typedef {
    my ( $from, $to ) = @_;
    
    return +{ type    => 'typedef', 
              subtype => 'simple',
              FROM    => $from, 
              TO      => $to, };
}

=over

=item __process_typedef 

Push a new entry into either <namespace_name>.typedef or std.typedef 

=back

=cut

sub __process_typedef {
    my ( $entry, $entries, $namespaces, $types ) = @_;
    
    # subtype:
    # class/struct/enum/union/fpointer/simple
    
}

=over 

=item _process

Re-group current content by namespace, store as on-disk files. 

B<NOTE>: Create a new typemap entry for raw function pointer parameter
in function declaration. 

B<NOTE>: Function parameter name is stripped in this phase. 

B<NOTE>: Function PROPERTY field is stripped in this phase. 

=back

=cut

sub _process {
    my ( $entries, $root_dir ) = @_;
    
    my $namespaces = [];
    my $types      = [];
    my $entries    = [];
    
    foreach my $entry (@$entries) {
        if ($entry->{type} eq 'accessibility') {
            __process_accessibility(
                $entry, $entries, $namespaces, $types);
        }
#        elsif ($entry->{type} eq 'macro') {
#            __process_macro(
#                $entry, $entries, $namespaces, $types);
#        }
        elsif ($entry->{type} eq 'typedef') {
            __process_typedef(
                $entry, $entries, $namespaces, $types);
        }
        elsif ($entry->{type} eq 'function') {
            __process_function(
                $entry, $entries, $namespaces, $types);
        }
        elsif ($entry->{type} eq 'class') {
            __process_class(
                $entry, $entries, $namespaces, $types);
        }
        elsif ($entry->{type} eq 'struct') {
            __process_struct(
                $entry, $entries, $namespaces, $types);
        }
        elsif ($entry->{type} eq 'union') {
            # union stays untouched
            __process_union(
                $entry, $entries, $namespaces, $types);
        }
        elsif ($entry->{type} eq 'extern') {
            __process_extern(
                $entry, $entries, $namespaces, $types);
        }
        elsif ($entry->{type} eq 'namespace') {
            __process_namespace(
                $entry, $entries, $namespaces, $types);
        }
        else {
            # drop in <namespace_name>.unknown
            __process_unknown(
                $entry, $entries, $namespaces, $types);
        }
    }
}

sub main {
    usage() unless @ARGV = 2;
    my ( $in, $out ) = @ARGV;
    die "file not found" unless -f $in;
    die "directory not found" unless -d $out;
    
    local ( *HEADER );
    open HEADER, '<', $in or die "cannot open file: $!";
    my $cont = do { local $/; <HEADER>; };
    close HEADER;
    my ( $entries ) = Load($cont);
    _process($entries, $out);
    
    exit 0;
}

&main;
