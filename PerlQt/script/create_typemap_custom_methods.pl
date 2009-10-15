#!/usr/bin/perl -w

################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

=head1 DESCRIPTION

A fake bin which contains custom methods for __analysis_type AUTOLOAD.

=cut

# QT template types
# invoke of each will instantiate new xs/pm code source files from
# specific templates 
# to serve requested template type
sub Q3PtrList {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_Q3PTRLIST', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'Q3PtrList<'. $sub_c_type. '>';
    # t_type same as type
    # which contains sub-type information
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        # new template type
        my $new_entry = {};
        $new_entry->{name}      = 'Q3PtrList';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        # mark done
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    # record in main typemap
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub Q3ValueList {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEPLATE} = 1;
    $entry->{type}   = join('__', 'T_Q3VALUELIST', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'Q3ValueList<'. $sub_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'Q3ValueList';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QFlags {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEPLATE} = 1;
    $entry->{type}   = join('__', 'T_QFLAGS', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QFlags<'. $sub_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QFlags';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QList {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QLIST', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QList<'. $sub_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QList';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QFuture {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QFUTURE', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QFuture<'. $sub_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QFuture';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QVector {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QVECTOR', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QVector<'. $sub_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QVector';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QSet {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QSET', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QSet<'. $sub_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QSet';
        $new_entry->{type}      = $new_entry->{name};
        $new_entry->{ntype}     = $entry->{type};
        $new_entry->{argc}      = 1;
        $new_entry->{item_type} = $sub_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QMap {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my @sub_key   = ();
    my @sub_value = ();
    # locate the start index of value part
    # NOTE: QMap< int *, QString >
    my $index_value = 1;
    for (my $i = 1; $i <= $#sub_entry; $i++) {
        unless (exists $sub_entry[$i]->{IS_CONST} or 
              exists $sub_entry[$i]->{IS_PTR} or 
                exists $sub_entry[$i]->{IS_REF}) {
            # not a part of key
            $index_value = $i;
            last;
        }
    }
    @sub_key   = splice @sub_entry, 0, $index_value;
    @sub_value = @sub_entry;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QMAP', 
           map { $_->{t_type} } @sub_key, @sub_value);
    my $key_c_type   = join(' ', map { $_->{c_type} } @sub_key);
    my $value_c_type = join(' ', map { $_->{c_type} } @sub_value);
    $entry->{c_type} = 'QMap<'. 
      $key_c_type. ','. $value_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QMap';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = 2;
        $new_entry->{key_type}   = $key_c_type;
        $new_entry->{value_type} = $value_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QMultiMap {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my @sub_key   = ();
    my @sub_value = ();
    # locate the start index of value part
    # NOTE: QMultiMap< int *, QString >
    my $index_value = 1;
    for (my $i = 1; $i <= $#sub_entry; $i++) {
        unless (exists $sub_entry[$i]->{IS_CONST} or 
              exists $sub_entry[$i]->{IS_PTR} or 
                exists $sub_entry[$i]->{IS_REF}) {
            # not a part of key
            $index_value = $i;
            last;
        }
    }
    @sub_key   = splice @sub_entry, 0, $index_value;
    @sub_value = @sub_entry;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QMULTIMAP', 
           map { $_->{t_type} } @sub_key, @sub_value);
    my $key_c_type   = join(' ', map { $_->{c_type} } @sub_key);
    my $value_c_type = join(' ', map { $_->{c_type} } @sub_value);
    $entry->{c_type} = 'QMultiMap<'. 
      $key_c_type. ','. $value_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QMultiMap';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = 2;
        $new_entry->{key_type}   = $key_c_type;
        $new_entry->{value_type} = $value_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QPair {
    my @sub_entry  = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my @sub_first  = ();
    my @sub_second = ();
    # locate the start index of second part
    # NOTE: QPair< int *, QString *>
    my $index_second = 1;
    for (my $i = 1; $i <= $#sub_entry; $i++) {
        unless (exists $sub_entry[$i]->{IS_CONST} or 
              exists $sub_entry[$i]->{IS_PTR} or 
                exists $sub_entry[$i]->{IS_REF}) {
            # not a part of key
            $index_second = $i;
            last;
        }
    }
    @sub_first  = splice @sub_entry, 0, $index_second;
    @sub_second = @sub_entry;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QPAIR', 
           map { $_->{t_type} } @sub_first, @sub_second);
    my $first_c_type  = join(' ', map { $_->{c_type} } @sub_first);
    my $second_c_type = join(' ', map { $_->{c_type} } @sub_second);
    $entry->{c_type} = 'QPair<'. 
      $first_c_type. ','. $second_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}        = 'QPair';
        $new_entry->{type}        = $new_entry->{name};
        $new_entry->{ntype}       = $entry->{type};
        $new_entry->{argc}        = 2;
        $new_entry->{first_type}  = $first_c_type;
        $new_entry->{second_type} = $second_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QHash {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    my @sub_key   = ();
    my @sub_value = ();
    # locate the start index of value part
    # NOTE: QHash< int *, QString >
    my $index_value = 1;
    for (my $i = 1; $i <= $#sub_entry; $i++) {
        unless (exists $sub_entry[$i]->{IS_CONST} or 
              exists $sub_entry[$i]->{IS_PTR} or 
                exists $sub_entry[$i]->{IS_REF}) {
            # not a part of key
            $index_value = $i;
            last;
        }
    }
    @sub_key   = splice @sub_entry, 0, $index_value;
    @sub_value = @sub_entry;
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QHASH', 
           map { $_->{t_type} } @sub_key, @sub_value);
    my $key_c_type   = join(' ', map { $_->{c_type} } @sub_key);
    my $value_c_type = join(' ', map { $_->{c_type} } @sub_value);
    $entry->{c_type} = 'QHash<'. 
      $key_c_type. ','. $value_c_type. '>';
    $entry->{t_type} = $entry->{type};
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QHash';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = 2;
        $new_entry->{key_type}   = $key_c_type;
        $new_entry->{value_type} = $value_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

1;

=head1 AUTHOR

Copyright (C) 2007 - 2009 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

