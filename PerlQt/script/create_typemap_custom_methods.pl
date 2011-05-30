#!/usr/bin/perl -w
# Author: Dongxu Ma

=head1 DESCRIPTION

A fake bin which contains custom methods for __analysis_type AUTOLOAD.

=cut

package QIntegerForSizeof;

sub Unsigned {
    my ( $self, ) = @_;
    my $entry = {};
    $entry->{type}   = 'T_UV';
    $entry->{c_type} = $self->{c_type}. '::Unsigned';
    $entry->{t_type} = 'T_UV';
    return $entry;
}

package main;

sub __parse_sub_entries {
    my ( @sub_entry, ) = @_;
    
    my $sub_entries = [];
    while (@sub_entry) {
        my $index;
        for ($index = 1; $index <= $#sub_entry; $index++) {
            unless (exists $sub_entry[$index]->{IS_CONST} or 
                      exists $sub_entry[$index]->{IS_PTR} or 
                        exists $sub_entry[$index]->{IS_REF}) {
                last;
            }
        }
        push @$sub_entries, [ splice @sub_entry, 0, $index ];
    }
    return $sub_entries;
}

# QT template types
# invoke of each will instantiate new xs/pm code source files from
# specific templates 
# to serve requested template type
sub Q3PtrList {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # Q3PtrList<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_Q3PTRLIST', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'Q3PtrList<'. $sub_c_type. '>';
    # t_type same as type
    # which contains sub-type information
    $entry->{t_type} = 'T_Q3PTRLIST';
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
    # Q3ValueList<type>
    my $entry     = {};
    $entry->{IS_TEPLATE} = 1;
    $entry->{type}   = join('__', 'T_Q3VALUELIST', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'Q3ValueList<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_Q3VALUELIST';
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
    # QFlags<type>
    my $entry     = {};
    $entry->{IS_TEPLATE} = 1;
    $entry->{type}   = join('__', 'T_QFLAGS', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QFlags<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QFLAGS';
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
sub QIntegerForSizeof {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QIntegerForSizeof<type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = 
      join('__', 'T_QINTEGERFORSIZEOF', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QIntegerForSizeof<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QINTEGERFORSIZEOF';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QIntegerForSizeof';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{item_type}  = $sub_class[0];
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return bless $entry, 'QIntegerForSizeof';
}
sub QList {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QList<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QLIST', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QList<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QLIST';
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

sub QDBusReply {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QDBusReply<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QDBUSREPLY', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QDBusReply<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QDBUSREPLY';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QDBusReply';
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
    # QFuture<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QFUTURE', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QFuture<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QFUTURE';
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

sub QExplicitlySharedDataPointer {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QExplicitlySharedDataPointer<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QEXPLICITLYSHAREDDATAPOINTER', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QExplicitlySharedDataPointer<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QEXPLICITLYSHAREDDATAPOINTER';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QExplicitlySharedDataPointer';
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

sub QAbstractXmlForwardIterator {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QAbstractXmlForwardIterator<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QABSTRACTXMLFORWARDITERATOR', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QAbstractXmlForwardIterator<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QABSTRACTXMLFORWARDITERATOR';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}      = 'QAbstractXmlForwardIterator';
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

sub QScopedPointer {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QScopedPointer<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QSCOPEDPOINTER', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QScopedPointer<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QSCOPEDPOINTER';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QScopedPointer';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub QVector {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QVector<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QVECTOR', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QVector<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QVECTOR';
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
    # QSet<type>
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = join('__', 'T_QSET', 
                            map { $_->{t_type} } @sub_entry);
    my $sub_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'QSet<'. $sub_c_type. '>';
    $entry->{t_type} = 'T_QSET';
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
    # QMap<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QMAP', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QMap<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QMAP';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QMap';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        $new_entry->{key_type}   = $sub_class[0];
        $new_entry->{value_type} = $sub_class[1];
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QMultiMap {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QMultiMap<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QMULTIMAP', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QMultiMap<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QMULTIMAP';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QMultiMap';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        $new_entry->{key_type}   = $sub_class[0];
        $new_entry->{value_type} = $sub_class[1];
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QPair {
    my @sub_entry  = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QPair<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QPAIR', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QPair<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QPAIR';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}        = 'QPair';
        $new_entry->{type}        = $new_entry->{name};
        $new_entry->{ntype}       = $entry->{type};
        $new_entry->{argc}        = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}
sub QHash {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QHash<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_QHASH', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QHash<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QHASH';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QHash';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        $new_entry->{key_type}   = $sub_class[0];
        $new_entry->{value_type} = $sub_class[1];
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub QGenericMatrix {
    my @sub_entry = @_;
    
    # for (my $i = 0; $i < 2; $i++) {
    #     $sub_entry[$i] = {
    #         type   => $sub_entry[$i],
    #         t_type => $sub_entry[$i],
    #         c_type => $sub_entry[$i],
    #     };
    # }
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # QGenericMatrix<m, n, t>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry     = {};
    $entry->{IS_TEMPLATE} = 3;
    $entry->{type}   = 
      join('__', 'T_QGENERICMATRIX', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'QGenericMatrix<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_QGENERICMATRIX';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'QGenericMatrix';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub std_less {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # std::less<type>
    my @sub_class = @sub_entry;
    my $entry  = {};
    $entry->{IS_TEMPLATE} = 1;
    $entry->{type}   = 
      join('__', 'T_STD_LESS', map { $_->{t_type} } @sub_entry);
    my $item_c_type = join(' ', map { $_->{c_type} } @sub_entry);
    $entry->{c_type} = 'std::less<'. $item_c_type. '>';
    $entry->{t_type} = 'T_STD_LESS';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'std::less';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = 1;
        $new_entry->{item_type}  = $item_c_type;
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub std_map {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # std::map<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry  = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_STD_MAP', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'std::map<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_STD_MAP';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'std::map';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub std_pair {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # std::pair<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry  = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_STD_PAIR', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'std::pair<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_STD_PAIR';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'std::pair';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub std_vector {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # std::vector<type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry  = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_STD_VECTOR', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'std::vector<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_STD_VECTOR';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'std::vector';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub std_set {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # std::set<type, type, type>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry  = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_STD_SET', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'std::vector<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_STD_SET';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'std::set';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

sub std_basic_string {
    my @sub_entry = @_;
    
    our ( %TYPE_KNOWN, @TYPE_TEMPLATE, );
    # std::set<type, traits, alloc>
    my $sub_entries = __parse_sub_entries(@sub_entry);
    my @sub_class = ();
    for (my $i = 0; $i < @$sub_entries; $i++) {
        push @sub_class, 
          join(' ', map { $_->{c_type} } @{ $sub_entries->[$i] });
    }
    my $entry  = {};
    $entry->{IS_TEMPLATE} = 2;
    $entry->{type}   = 
      join('__', 'T_STD_BASIC_STRING', map { $_->{t_type} } @sub_entry);
    $entry->{c_type} = 'std::basic_string<'. join(',', @sub_class). '>';
    $entry->{t_type} = 'T_STD_BASIC_STRING';
    # record type info in @TYPE_TEMPLATE
    unless (exists $_TYPE_TEMPLATE{$entry->{t_type}}) {
        my $new_entry = {};
        $new_entry->{name}       = 'std::basic_string';
        $new_entry->{type}       = $new_entry->{name};
        $new_entry->{ntype}      = $entry->{type};
        $new_entry->{argc}       = @sub_class;
        for (my $i = 0; $i < @sub_class; $i++) {
            $new_entry->{'class'. $i. '_type'} = $sub_class[$i];
        }
        push @TYPE_TEMPLATE, $new_entry;
        $_TYPE_TEMPLATE{$entry->{t_type}} = 1;
    }
    $TYPE_KNOWN{$entry->{c_type}} = $entry->{type};
    return $entry;
}

1;

=head1 AUTHOR

Copyright (C) 2007 - 2011 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

