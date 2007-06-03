#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );
use Fcntl qw(O_RDWR O_TRUNC O_CREAT :flock);
use YAML;
use File::Spec ();

=head1 DESCIPTION

Group formatted QTEDI production by namespace.

For each namespace there will be files generated as below:

  1. <namespace_name>.typedef            : all typedefs
  2. <namespace_name>.enum               : all enums
  3. <namespace_name>.function.public    : all public member functions
  4. <namespace_name>.function.protected : all protected member functions
  5. <namespace_name>.signal             : all signals
  6. <namespace_name>.slot.public        : all public slots
  7. <namespace_name>.slot.protected     : all protected slots
  8. <namespace_name>.function           : no use

B<NOTE>: 'namespace' here, as a generic form, stands for any
full-qualified class/struct/namespace name in C/CXX. 

B<NOTE>: filename length limit is _PC_NAME_MAX on POSIX,
normally this should not be an issue. 

B<NOTE>: a special namespace - <NAMESPACE_DEFAULT()>, will hold any
entry which doesn't belong to other namespace. 

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

sub usage {
    print STDERR << "EOU";
usage: $0 <default_namespace> <formatted_qtedi_output.yaml> <output_directory>
EOU
    exit 1;
}

# private consts
# TODO: Getopt::Long
sub ARGV_INDEX_NAMESPACE_DEFAULT() { 0 }
# see __qt_get_module_name
sub ARGV_INDEX_FILE_INPUT() { 1 }

sub NAMESPACE_DEFAULT { $ARGV[ARGV_INDEX_NAMESPACE_DEFAULT] }

sub VISIBILITY_PUBLIC { 
    +{ type => 'accessibility', VALUE => [ 'public' ], } 
}

sub VISIBILITY_PRIVATE {
    +{ type => 'accessibility', VALUE => [ 'private' ], }
}

=over

=item write_to_file

A configurable hook to save content into file(s). How/where to
create such file and the file name is totally blind for caller. 

B<NOTE>: Currently create the file with a full-qualified
namespace string as its name. 

=back

=cut

sub write_to_file {
    my ( $hcont, $root_dir ) = @_;
    
    my $NS_DELIMITER = q(::);
    my $FN_DELIMITER = q(__);
    #die "root directory not found" unless -d $root_dir;
    my $filename;
    foreach my $k (keys %$hcont) {
        ( $filename = $k ) =~
          s/(?:\Q$NS_DELIMITER\E)+/$FN_DELIMITER/ge;
        $filename = File::Spec::->catfile($root_dir, $filename);
        #print STDERR $filename, "\n";
        local ( *OUT );
        sysopen OUT, $filename, O_CREAT|O_RDWR or 
          die "cannot open file to read/write: $!";
        until (flock OUT, LOCK_EX) { sleep 3; }
        seek OUT, 0, 0;
        my $old = do { local $/; <OUT>};
        seek OUT, 0, 0;
        truncate OUT, length($old);
        if ($old) {
            # merge with existing entries
            if (ref $hcont->{$k} eq 'HASH') {
                print OUT Dump(
                    { %{ (Load($old))[0] }, %{ $hcont->{$k} } });
            }
            else {
                print OUT Dump(
                    [ @{ (Load($old))[0] }, @{ $hcont->{$k} } ]);
            }
        }
        else {
            print OUT Dump($hcont->{$k});
        }
        close OUT or die "cannot write to file: $!";
    }
}

=over

=item __process_accessibility

Adapt content of @$type and @$visibility accordingly. Invoked by _process.

=back

=cut

sub __process_accessibility {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    
    # push @$type and @$visibility stacks, others left untouched
    # empty first
    splice @$type, 0, scalar(@$type) if @$type;
    splice @$visibility, 0, scalar(@$visibility) if @$visibility;
    foreach my $t (@{$entry->{VALUE}}) {
        if ($t eq 'Q_SIGNALS' or $t eq 'signals') {
            # Q_SIGNALS/signals
            # SIGNAL HAS NO VISIBILITY IN QT
            push @$type, 'signal';
        }
        elsif ($t eq 'Q_SLOTS' or $t eq 'slots') {
            # Q_SLOTS/slots
            push @$type, 'slot';
        }
        else {
            # public/private/protected
            push @$visibility, $t;
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

Push new entries into either <namespace_name>.typedef or
<NAMESPACE_DEFAULT>.typedef accordingly. 

B<NOTE>: typedef might define new container type as side-effect. 

=back

=cut

sub __process_typedef {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    
    # subtype:
    # class/struct/enum/union/fpointer/simple
    my $entries_to_create = [];
    if ($entry->{subtype} eq 'simple') {
        push @$entries_to_create, 
          [$entry->{FROM}, $entry->{TO}];
    }
    elsif ($entry->{subtype} eq 'fpointer') {
        push @$entries_to_create, 
          [$entry->{FROM}, $entry->{TO}];
        # keep prototype info for future use
        push @$entries_to_create, 
          [$entry->{PROTOTYPE}, $entry->{FROM}];
        # TODO: template type inside fpointer
    }
    else {
        # container types
        # typedef permits self-define of container type within
        # typedef enum FROM {} TO;
        # will: 
        #     1. define enum itself
        #     2. map enum FROM to TO
        my $gen_type = sub { 'T_'. uc($entry->{subtype}) };
        if (ref $entry->{FROM} eq 'HASH') {
            if (exists $entry->{FROM}->{NAME}) {
                # typedef enum FROM {} TO;
                # has explicit name
                push @$entries_to_create, 
                  [$entry->{FROM}->{NAME}, $entry->{TO}];
                push @$entries_to_create, 
                  [$gen_type->(), $entry->{FROM}->{NAME}];
            }
            else {
                # typedef enum {} TO;
                push @$entries_to_create, 
                  [$gen_type->(), $entry->{TO}];
                # fill name for anonymous enum/class/struct/union typedef
                $entry->{FROM}->{NAME} = $entry->{TO};
            }
        }
        else {
            # typedef enum FROM TO;
            if ($entry->{FROM} =~ m/^(.*?)\*(?:\*| )*\s*$/io) {
                # check for pointer def
                # FIXME: something like "Qt::*funcpointer"
                # NOTE: "STRUCT * * "
                push @$entries_to_create, 
                  [$gen_type->(). '_PTR', $entry->{FROM}];
                my $type_without_pointer = $1;
                $type_without_pointer =~ s/\s+$//io;
                push @$entries_to_create,
                  [$gen_type->(), $type_without_pointer];
            }
            else {
                push @$entries_to_create, 
                  [$gen_type->(), $entry->{FROM}];
            }
            push @$entries_to_create, 
              [$entry->{FROM}, $entry->{TO}];
        }
        # push built-in anonymous define
        if (ref $entry->{FROM} eq 'HASH') {
            if ($entry->{subtype} eq 'enum' and 
                  exists $entry->{FROM}->{VALUE}) {
                __process_enum(
                    $entry->{FROM}, $entries, $namespace, $type, $visibility);
            } elsif ($entry->{subtype} eq 'class' and 
                       exists $entry->{FROM}->{BODY}) {
                __process_class(
                    $entry->{FROM}, $entries, $namespace, $type, $visibility);
            } elsif ($entry->{subtype} eq 'struct' and 
                       exists $entry->{FROM}->{BODY}) {
                __process_struct(
                    $entry->{FROM}, $entries, $namespace, $type, $visibility);
            } else {
                # TODO: union
            }
        }
    }
    # store
    my $TYPE = 'typedef';
    foreach my $p (@$entries_to_create) {
        my ( $f, $t ) = @$p;
        if (@$namespace) {
            # explicit namespace
            $entries->{$namespace->[-1]. '.'. $TYPE}->{$t} = $f;
        }
        else {
            if ($t =~ m/\:\:/io) {
                # namespace prefix found
                my @t = split /\:\:/, $t;
                $t = pop @t;
                my $n = join('::', @t);
                $entries->{$n. '.'. $TYPE}->{$t} = $f;
            }
            else {
                # global typedef
                $entries->{NAMESPACE_DEFAULT(). '.'. $TYPE}->{$t} = $f;
            }
        }
    }
}

=over

=item __process_enum

Push a new enum entry into either <namespace>.enum or
<NAMESPACE_DEFAULT>.enum 

=back

=cut

sub __process_enum {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    
    #print "enum found: ", $entry->{NAME}, "\n";
    my $entry_to_create = {};
    $entry_to_create->{NAME}  = $entry->{NAME} if 
      exists $entry->{NAME};
    $entry_to_create->{VALUE} = $entry->{VALUE};
    if (exists $entry->{NAME}) {
        # push new typedef
        __process_typedef(__gen_simple_typedef('T_ENUM',
                                               $entry->{NAME}),
                          $entries, $namespace, $type, $visibility);
    }
    # store
    my $TYPE = 'enum';
    if (@$namespace) {
        push @{$entries->{$namespace->[-1]. '.'. $TYPE}}, $entry_to_create;
    }
    else {
        push @{$entries->{NAMESPACE_DEFAULT(). '.'. $TYPE}}, $entry_to_create;
    }
}

=over

=item __process_function

Push a function entry into possible files: 

  1. <namespace>.function.public
  2. <namespace>.function.protected
  3. <namespace>.slot.public
  4. <namespace>.slot.protected
  5. <namespace>.function
  6. <namespace>.signal
  7. <namespace>.friend
  8. <NAMESPACE_DEFAULT>.function

B<NOTE>: One of the most important missions in this phase is to gather
overload functions. Since overload functions might be pushed from
different header files. 

=back

=cut 

sub __process_function {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    
    delete $entry->{type};
    $entry->{operator} = $entry->{subtype};
    delete $entry->{subtype};
    # check PROPERTY
    # for static and friend declarations
    my $is_friend_decl = 0;
    if (exists $entry->{PROPERTY}) {
        foreach my $p (@{$entry->{PROPERTY}}) {
            if ($p eq 'static') {
                $entry->{static} = 1;
            } elsif ($p eq 'friend') {
                $is_friend_decl = 1;
            }
        }
        delete $entry->{PROPERTY};
    }
    if (exists $entry->{PARAMETER}) {
        foreach my $p (@{$entry->{PARAMETER}}) {
            if ($p->{TYPE} =~ m/^T\_FPOINTER\_/o) {
                # check function pointer parameter
                # push into typedef
                __process_typedef(
                    __gen_simple_typedef($p->{NAME}, $p->{TYPE}), 
                    $entries, $namespace, $type, $visibility);
            }
            elsif ($p->{TYPE} =~ m/^T\_ARRAY\_/o) {
                # check array pointer parameter
                # push into typedef
                __process_typedef(
                    __gen_simple_typedef($p->{NAME}, $p->{TYPE}),
                    $entries, $namespace, $type, $visibility);
            }
        }
    }
    # store
    if ($is_friend_decl) {
        # friend function declaration pushed into <namespace>.friend
        my $TYPE = 'friend';
        my $k = $namespace->[-1]. '.'. $TYPE;
        push @{$entries->{$k}}, $entry;
    }
    else {
        my $TYPE = 'function';
        if (@$namespace) {
            my $k = join('.', $namespace->[-1], 
                         scalar(@$type) ? $type->[-1] : $TYPE, 
                         scalar(@$visibility) ? $visibility->[-1] : ());
            push @{$entries->{$k}}, $entry;
        } else {
            if ($entry->{NAME} =~ m/\:\:/io) {
                # namespace delimiter found
                # push into specific namespace
                my ( @e ) = split /\:\:/, $entry->{NAME};
                $entry->{NAME} = pop @e;
                push @{$entries->{join('::', @e) . '.'. $TYPE}}, $entry;
            } else {
                push @{$entries->{NAMESPACE_DEFAULT(). '.'. $TYPE}},
                  $entry;
            }
        }
    }
}

# get QT-specific module info from file path
sub __get_qt_module_name {
    return (File::Spec::->splitdir($ARGV[ARGV_INDEX_FILE_INPUT]))[-2];
}

# internal 
# process a class or struct entry
sub __process_class_or_struct {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    
    if (exists $entry->{PROPERTY} and 
          grep { $_ eq 'friend'} @{$entry->{PROPERTY}}) {
        # friend decl
        delete $entry->{PROPERTY};
        # store
        my $TYPE = 'friend';
        push @{$entries->{$namespace->[-1]. '.'. $TYPE}}, $entry;
    }
    else {
        # push new typedef
        if (exists $entry->{NAME}) {
            # make sure not an anonymous class/struct
            __process_typedef(__gen_simple_typedef('T_'. uc($entry->{type}), 
                                                   $entry->{NAME}), 
                              $entries, $namespace, $type, $visibility);
        }
        if (exists $entry->{BODY} and @{$entry->{BODY}} and 
              not exists $entry->{VARIABLE}) {
            # normal full decl 
            # make sure not an anymous struct/class variable like
            # struct { int i; } d;
            my $entry_to_create = {};
            # keep PROPERTY for future reference
            $entry_to_create->{PROPERTY} = $entry->{PROPERTY} if 
              exists $entry->{PROPERTY};
            # required class-specific meta information
            $entry_to_create->{ISA} = $entry->{ISA} if 
              exists $entry->{ISA};
            $entry_to_create->{TYPE} = $entry->{type};
            # push new typedef
            __process_typedef(__gen_simple_typedef('T_'. uc($entry->{type}),
                                                   $entry->{NAME}),
                              $entries, $namespace, $type, $visibility);
            # push new namespace
            my $new_namespace = @$namespace ?
              $namespace->[-1]. '::'. $entry->{NAME} : $entry->{NAME};
            push @$namespace, $new_namespace;
            # get QT module info 
            $entry_to_create->{MODULE} = __get_qt_module_name();
            # store
            my $TYPE = 'meta';    
            $entries->{$namespace->[-1]. '.'. $TYPE} = $entry_to_create;
            # process body
            # push 'private' as initial visibility
            __process_accessibility($entry->{type} eq 'class' ?
                                      VISIBILITY_PRIVATE() :
                                        VISIBILITY_PUBLIC(), $entries, 
                                    $namespace, $type, $visibility);
            __process_loop($entry->{BODY}, $entries, 
                           $namespace, $type, $visibility);
            # leave class declaration
            # pop current namespace
            pop @$namespace;
        }   
    }
}

=over 

=item __process_class

Create a new file <namespace>.meta for class, keep specific
information inside. Push new items into @$namespace, @$type and
@$visibility stacks. 

Create new typedef entry. 

=back

=cut

sub __process_class {
    &__process_class_or_struct;
}

=over

=item __process_struct

Similar as __process_class. See above. 

=back

=cut

sub __process_struct {
    &__process_class_or_struct;
}

=over

=item __process_extern

Currently pay no attention to extern stuff. Normally it is used to
import C symbols into C++ code or to bridge an existing variable in 
another namespace. 

=back

=cut

sub __process_extern {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    # noop but warn
    print STDERR "TODO: got an extern keyword inside: ", $ARGV[0],
      "\n";
}

=over

=item __process_namespace

Recursively process namespace body. While no <namespace>.meta
created. 

=back

=cut

sub __process_namespace {
    my ( $entry, $entries, $namespace, $type, $visibility ) = @_;
    
    #print "namespace found: ", $entry->{NAME}, "\n";
    my $entry_to_create = {};
    $entry_to_create->{NAME}   = $entry->{NAME};
    $entry_to_create->{TYPE}   = $entry->{type};
    $entry_to_create->{MODULE} = '';
    # push new namespace
    # namespace could _ONLY_ be nested in another namespace
    my $new_namespace = @$namespace ?
      $namespace->[-1]. '::'. $entry->{NAME} : $entry->{NAME};
    push @$namespace, $new_namespace;
    # store
    my $TYPE = 'meta';
    $entries->{$namespace->[-1]. '.'. $TYPE} = $entry_to_create;
    # process body
    __process_loop($entry->{BODY}, $entries, 
                   $namespace, $type, $visibility);
    # leave namespace declaration
    # pop current namespace
    pop @$namespace;
}

=over 

=item __process_loop

Internal use only. Process each entry inside current list body. 

=back

=cut

sub __process_loop {
    my ( $list, $entries, $namespace, $type, $visibility ) = @_;
    
    foreach my $entry (@$list) {
        if ($entry->{type} eq 'accessibility') {
            __process_accessibility(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'macro') {
            # macro stripped
            #__process_macro(
            #    $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'typedef') {
            __process_typedef(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'enum') {
            __process_enum(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'fpointer') {
            # fpointer stripped
            #__process_fpointer(
            #    $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'function') {
            __process_function(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'class') {
            __process_class(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'struct') {
            __process_struct(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'union') {
            # union stripped
            #__process_union(
            #    $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'extern') {
            __process_extern(
                $entry, $entries, $namespace, $type, $visibility);
        }
        elsif ($entry->{type} eq 'namespace') {
            __process_namespace(
                $entry, $entries, $namespace, $type, $visibility);
        }
    }
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
    my ( $list, $root_dir ) = @_;
    
    # internal stacks
    # namespace stack
    my $namespace       = [];
    # type stack
    # differentiate normal function/signal/slot
    my $type            = [];
    # visibility stack
    # differentiate public/protected
    my $visibility      = [];
    # entries to store, grouped by <namespace>.<type>[.<accessibility>]
    my $entries         = {};
    # recursively process each entry inside list body
    __process_loop($list, $entries, $namespace, $type, $visibility);
    # make <NAMESPACE_DEFAULT>.meta
    $entries->{NAMESPACE_DEFAULT. '.meta'} = { 
        type => 'namespace', MODULE => '', };
    # special patch to <NAMESPACE_DEFAULT>.function
    # rename to <NAMESPACE_DEFAULT>.function.public
    if (exists $entries->{NAMESPACE_DEFAULT. '.function'}) {
        $entries->{NAMESPACE_DEFAULT. '.function.public'} = 
          $entries->{NAMESPACE_DEFAULT. '.function'};
        delete $entries->{NAMESPACE_DEFAULT. '.function'};
    }
    # actual write
    write_to_file($entries, $root_dir);
}

sub main {
    usage() unless @ARGV == 3;
    my ( undef, $in, $out ) = @ARGV;
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
