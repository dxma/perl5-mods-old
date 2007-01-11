package BerkeleyDB::SecIndices::Accessor;

use 5.005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'const' => [ qw(ELCK EPUT EDEL EUPD EGET EGTS
                                     EDUP EEPT ELOCK TRUE
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'const'} } );

our @EXPORT = qw(EGET EGTS EEPT EPUT ELCK EUPD);

our $VERSION = '0.06';

use Carp qw(croak);
use BerkeleyDB;
use File::Spec ();
use Storable qw(freeze thaw);
local $Storable::canonical = 1;

# global container to hold _ALL_ related stuff
my $STUBS = {};

# max retry times to obtain a cdb lock
our $LOCK_RETRY_MAX = 5;

# path to database configuration file
# of YAML format
our $CONFIG;
my $_config;

# configurable callbacks
# refer to BerkeleyDB on how to write
our $CB_EXTRACT_SECKEY;
our $CB_DUP;
our $CB_DUPSORT;

# debug flag
# no debug ouput by default
our $DEBUG = 0;

sub ELCK() { -2; }
sub ELOCK() { ELCK(); }
sub EPUT() { -1; }
sub EDEL() { -1; }
sub EUPD() { -1; }
sub EGET() { -1; }
sub EGTS() { -1; }
sub EDUP() { -1; }
sub EEPT() { -3; }
sub TRUE() { 1;  }

BEGIN {
    if ($BerkeleyDB::db_version < 3.3) {
        croak("BerkeleyDB ver 3.3.x required!");
    }
}

# This section inits _ALL_ databases 
# _ALL_ db handlers are stored in $db_pool with specific keys
# the key is contructed according to keys %{$_config->{DATABASE}}

{
    use YAML ();
    ( $_config ) = YAML::LoadFile($CONFIG);
    # soft check
    croak("no database HOME found") unless 
      exists $_config->{HOME} and -d $_config->{HOME};
    croak("wrong database declaration") unless 
      ref $_config->{DATABASE} eq 'HASH';
    
    # Global Env for _ALL_ DBs
    # created in system shared memory by flag DB_SYSTEM_MEM
    # Shared memory key can also be specified in DB_CONFIG 
    my $Env = BerkeleyDB::Env::->new(
        -Home         => $_config->{HOME},
        #-Cachesize    => 2000000, 
        -ErrFile      => *STDERR, 
        -ErrPrefix    => __PACKAGE__, 
        -Flags        => DB_CREATE|DB_INIT_CDB|DB_INIT_MPOOL|DB_SYSTEM_MEM,
        -Verbose      => 1, 
    );
    croak("cannot create dbenv") unless $Env and $Env->status() == 0;
    my $DB = $_config->{DATABASE};
    # container to hold  _ALL_ dbs
    my $db_pool = {};
    # container to check required index fields for primary database
    my $required_index = {};
    
    # DIRTY CODE START
    no strict 'refs';
    my $getenv = '___dbenv';
    
    *$getenv = sub() { $Env; };
    
    my $makekey = sub {
        my ( $primary, $index ) = @_;
        if ($index) {
            return '_'. lc($primary). '_'. lc($index);
        }
        else {
            return '_'. lc($primary);
        }
    };
    
    my $_db_property = DB_DUP;
    if (defined $CB_DUPSORT and ref $CB_DUPSORT eq 'CODE') {
        $_db_property |= DB_DUPSORT;
    }
    foreach my $i (keys %$DB) {
        if ($i =~ m/INDEX$/o) {
            # index db
            # open SUBS
            foreach my $j (0 .. $#{$DB->{$i}->{SUBS}}) {
                my $params = {
                    -Filename   => $DB->{$i}->{FILE},
                    -Subname    => $DB->{$i}->{SUBS}->[$j],
                    -Flags      => DB_CREATE|DB_DIRECT_DB,
                    -Property   => $_db_property,
                    -Mode       => 0644,
                    -Env        => $Env,
                };
                if (defined $CB_DUP and ref $CB_DUP eq 'CODE') {
                    $params->{-Compare} = $CB_DUP;
                }
                if (defined $CB_DUPSORT and 
                      ref $CB_DUPSORT eq 'CODE') {
                    $params->{-DupCompare} = $CB_DUPSORT;
                }
                my $db = BerkeleyDB::Btree::->new(%$params);
                my $key = $makekey->($i, $DB->{$i}->{SUBS}->[$j]);
                #print 'key: ', $key, "\n";
                #print "CDS: ". $db->cds_enabled() ? 'true' : 'false', "\n";
                $db_pool->{$key} = $db;
                *$key = sub() { $db_pool->{$key}; };
            }
        }
        else {
            my $_type = 0; # Recno by default
            if (exists $DB->{$i}->{TYPE}) {
                # honor type
                #print STDERR $i, ": ", $DB->{$i}->{TYPE}, "\n";
                if ($DB->{$i}->{TYPE} eq 'Hash') {
                    $_type = 1;
                }
                elsif ($DB->{$i}->{TYPE} eq 'Btree') {
                    $_type = 2;
                }
                else {
                    $_type = 0;
                }
            }
            my $db;
            if ($_type == 0) {
                $db = BerkeleyDB::Recno::->new(
                    -Filename  => $DB->{$i}->{FILE},
                    -Flags     => DB_CREATE|DB_DIRECT_DB, 
                    -Mode      => 0644,
                    -Env       => $Env,
                );
            }
            elsif ($_type == 1) {
                $db = BerkeleyDB::Hash::->new(
                    -Filename  => $DB->{$i}->{FILE},
                    -Flags     => DB_CREATE|DB_DIRECT_DB, 
                    -Property  => DB_DUP,
                    -Mode      => 0644,
                    -Env       => $Env,
                );
            }
            else {
                $db = BerkeleyDB::Btree::->new(
                    -Filename  => $DB->{$i}->{FILE},
                    -Flags     => DB_CREATE|DB_DIRECT_DB, 
                    -Property  => DB_DUP,
                    -Mode      => 0644,
                    -Env       => $Env,
                );
            }
            
            my $key = $makekey->($i);
            $db_pool->{$key} = $db;
            *$key = sub() { $db_pool->{$key}; };
        }
    }

    # associate each index db with primary db
    foreach my $i (keys %$DB) {
        if ($i =~ m/INDEX$/o) {
            # BLAH_INDEX associated with $db_pool->{_blah}
            foreach my $j (0 .. $#{$DB->{$i}->{SUBS}}) {
                my $secondary = $makekey->($i, $DB->{$i}->{SUBS}->[$j]);
                ( my $p = $i ) =~ s/_INDEX$//o;
                my $primary   = $makekey->($p);
                push @{$required_index->{$p}}, $DB->{$i}->{SUBS}->[$j];
                
                unless (exists $db_pool->{$primary}) {
                    croak("database $primary not found");
                }
                unless (exists $db_pool->{$secondary}) {
                    croak("database $secondary not found");
                }
                my $_extract_seckey = sub {
                    my $pkey  = shift;
                    # $pdata is freezed by Storable
                    my $pdata = shift;
                    my $hcontent = thaw($pdata);
                    my $k = $hcontent->{$DB->{$i}->{SUBS}->[$j]};
                    #print STDERR 'secondary key: '. $k, "\n";
                    if (ref $k eq 'ARRAY') {
                        # special index for array
                        # array items should be recno
                        # FOR scenarios and cases
                        my $skey = '';
                        foreach (@$k) {
                            vec($skey, $_, 1) = 1;
                        }
                        $_[0] = $skey;
                    }
                    else {
                        # normal SCALAR
                        $_[0] = $k;
                    }
                    return 0;
                };
                
                my $rc;
                if (defined $CB_EXTRACT_SECKEY and 
                      ref $CB_EXTRACT_SECKEY eq 'CODE') {
                    $rc = $db_pool->{$primary}->associate(
                        $db_pool->{$secondary}, 
                        $CB_EXTRACT_SECKEY);
                }
                else {
                    $rc = $db_pool->{$primary}->associate(
                        $db_pool->{$secondary}, $_extract_seckey);
                }
                unless ($rc == 0) {
                    croak("cannot associate index $secondary ".
                            "with primary database $primary");
                }
            }
        }
    }
    
    # make accessor for each primary database
    foreach my $i (keys %$DB) {
        if ($i !~ m/INDEX$/o) {
            # primary database
            my $put   = 'put_'. lc($i);
            my $put2  = 'put2_'. lc($i);
            my $upd   = 'upd_'. lc($i);
            # TODO: update version 2
            my $upd2  = 'upd2_'. lc($i);
            my $get   = 'get_'. lc($i);
            my $gets  = 'get_'. lc($i). 's';
            my $count = '__'. lc($i). 's';
            my $dels  = 'del_'. lc($i). 's';
            $STUBS->{$i}->{PUT}   = sub { __PACKAGE__->$put(@_); };
            $STUBS->{$i}->{PUT2}  = sub { __PACKAGE__->$put2(@_); };
            $STUBS->{$i}->{UPD}   = sub { __PACKAGE__->$upd(@_); };
            #$STUBS->{$i}->{UPD2}  = sub { __PACKAGE__->$upd2(@_); };
            $STUBS->{$i}->{GET}   = sub { __PACKAGE__->$get(@_); };
            $STUBS->{$i}->{GETS}  = sub { __PACKAGE__->$gets(@_); };
            $STUBS->{$i}->{COUNT} = sub { __PACKAGE__->$count(@_); };
            $STUBS->{$i}->{DEL}   = sub { __PACKAGE__->$dels(@_); };
            
            if (exists $DB->{$i}->{TYPE} and 
                  ($DB->{$i}->{TYPE} eq 'Hash' or 
                     $DB->{$i}->{TYPE} eq 'Btree')) {
                *$put = sub {
                    my ( $self, $k, $hcontent ) = @_;
                    croak("ref $_[2] ne 'HASH'") unless 
                      ref $hcontent eq 'HASH';
                    # check required index fields
                    foreach my $field (@{$required_index->{$i}}) {
                        if (not exists $hcontent->{$field}) {
                            croak("required index field $field ".
                                    "not found");
                        }
                    }
                    my $fcontent = freeze($hcontent);
                    my $key = $makekey->($i);
                    # validate $lock
                    my $lock;
                    my $retry = 0;
                    LOCK:
                    {
                        $lock = $db_pool->{$key}->cds_lock();
                        last LOCK if defined $lock;
                        sleep 3;
                        redo LOCK if ++$retry < $LOCK_RETRY_MAX;
                    }
                    unless (defined $lock) {
                        return ELCK;
                    }
                    my $rc = $db_pool->{$key}->db_put(
                        $k, $fcontent, DB_NOOVERWRITE);
                    # no cache in memo
                    $db_pool->{$key}->db_sync();
                    $lock->cds_unlock();
                    return $rc == 0 ? TRUE : EPUT;
                };
                
                *$put2 = sub {
                    my ( $self, $rpairs ) = @_;
                    return TRUE if keys %$rpairs == 0;
                    
                    croak("ref $_[1] ne 'HASH'") unless 
                      ref $rpairs eq 'HASH';
                    # check required index fields
                    foreach my $field (@{$required_index->{$i}}) {
                        my $v;
                        while (( undef, $v ) = each %$rpairs) {
                            if (not exists $v->{$field}) {
                                croak("required index field $field ".
                                        "not found");
                            }
                        }
                    }
                    my $key = $makekey->($i);
                    # validate $lock
                    my $lock;
                    my $retry = 0;
                    LOCK:
                    {
                        $lock = $db_pool->{$key}->cds_lock();
                        last LOCK if defined $lock;
                        sleep 3;
                        redo LOCK if ++$retry < $LOCK_RETRY_MAX;
                    }
                    unless (defined $lock) {
                        return ELOCK;
                    }
                    
                    my ( $k, $v, $rc );
                    $rc = 0;
                    while (( $k, $v ) = each %$rpairs) {
                        $rc += $db_pool->{$key}->db_put(
                            $k, freeze($v), DB_NOOVERWRITE);
                    }
                    # no cache in memo
                    $db_pool->{$key}->db_sync();
                    $lock->cds_unlock();
                    return $rc == 0 ? TRUE : EPUT;
                };
            }
            else {
                # Recno by default
                *$put = sub {
                    my ( $self, @hcontent ) = @_;
                    croak("ref $_[1] ne 'HASH'") unless 
                      ref $hcontent[0] eq 'HASH';
                    # check required index fields
                    foreach my $field (@{$required_index->{$i}}) {
                        if (not exists $hcontent[0]->{$field}) {
                            croak("required index field $field ".
                                    "not found");
                        }
                    }
                    my @fcontent = map { freeze($_) } @hcontent;
                    my $key = $makekey->($i);
                    # validate $lock
                    my $lock;
                    my $retry = 0;
                    LOCK:
                    {
                        $lock = $db_pool->{$key}->cds_lock();
                        last LOCK if defined $lock;
                        sleep 3;
                        redo LOCK if ++$retry < $LOCK_RETRY_MAX;
                    }
                    unless (defined $lock) {
                        return ELCK;
                    }
                    my ( $k, $first_key, $rc );
                    $rc = 0;
                    foreach (@fcontent) {
                        $k = -1;
                        $rc += $db_pool->{$key}->db_put(
                            $k, $_, DB_APPEND);
                        $first_key = $k unless defined $first_key;
                    }
                    # no cache in memo
                    $db_pool->{$key}->db_sync();
                    $lock->cds_unlock();
                    return $rc == 0 ? $first_key : EPUT;
                };
                
                *$put2 = sub {
                    my ( $self, $hcontent_array, $key_array ) = @_;
                    return TRUE if @$hcontent_array == 0;
                    croak('ref $_[1]->[0] ne "HASH"') unless 
                      ref($hcontent_array->[0]) eq 'HASH';
                    # check required index fields
                    foreach my $field (@{$required_index->{$i}}) {
                        if (not exists $hcontent_array->[0]->{$field}) {
                            croak("required index field $field ".
                                    "not found");
                        }
                    }
                    my $key = $makekey->($i);
                    # validate $lock
                    my $lock;
                    my $retry = 0;
                    LOCK:
                    {
                        $lock = $db_pool->{$key}->cds_lock();
                        last LOCK if defined $lock;
                        sleep 3;
                        redo LOCK if ++$retry < $LOCK_RETRY_MAX;
                    }
                    unless (defined $lock) {
                        return ELOCK;
                    }
                    my ( $k, $rc, $rc_all );
                    $rc_all = 0;
                    foreach my $v (@$hcontent_array) {
                        $k = -1;
                        $rc = $db_pool->{$key}->db_put(
                            $k, freeze($v), DB_APPEND);
                        push @$key_array, $k if $rc == 0;
                        $rc_all += $rc;
                    }
                    # no cache in memo
                    $db_pool->{$key}->db_sync();
                    $lock->cds_unlock();
                    return $rc_all == 0 ? TRUE : EPUT;
                }; 
            }
            
            *$upd = sub {
                my ( $self, $k, $hcontent ) = @_;
                croak("ref $_[2] ne 'HASH'") unless 
                  ref $hcontent eq 'HASH';
                my ( $v, $rc );
                $v = '';
                my $key = $makekey->($i);
                # validate $lock
                my $lock;
                my $retry = 0;
                LOCK:
                {
                    $lock = $db_pool->{$key}->cds_lock();
                    last LOCK if defined $lock;
                    sleep 3;
                    redo LOCK if ++$retry < $LOCK_RETRY_MAX;
                }
                unless (defined $lock) {
                    return ELCK;
                }
                # FIXME evaluate $cursor
                my $cursor = $db_pool->{$key}->db_cursor(DB_WRITECURSOR);
                $rc = $cursor->c_get($k, $v, DB_SET);
                #print STDERR "key : $k\n";
                #print STDERR "rc  : $rc\n";
                return EUPD unless $rc == 0;
                my $content = thaw($v);
                foreach (keys %$hcontent) {
                    $content->{$_} = $hcontent->{$_};
                }
                my $fcontent = freeze($content);
                $rc = $cursor->c_put($k, $fcontent, DB_CURRENT);
                # no cache in memo
                $db_pool->{$key}->db_sync();
                $lock->cds_unlock();
                $cursor->c_close();
                return $rc == 0 ? 0 : EUPD;
            };
            
            *$get = sub {
                my ( $self, $k ) = @_;
                my $key = $makekey->($i);
                my ( $fcontent, $rc );
                $rc = $db_pool->{$key}->db_get($k, $fcontent);
                #print STDERR "rc = ", $rc, "\n";
                if ($rc == 0) {
                    return thaw($fcontent);
                }
                else {
                    if ($rc == DB_NOTFOUND or $rc == DB_KEYEMPTY) {
                        return EEPT;
                    }
                    else {
                        if ($DEBUG) {
                            print STDERR __PACKAGE__, ": get_xxx failed\n";
                        }
                        return EGET;
                    }
                }
            };

            *$gets = sub {
                my ( $self, $n, $desc, $offset ) = @_;
                my $key = $makekey->($i);
                my ( $k, $fcontent, $rc );
                $k = -1;
                $desc ||= 0;
                my $cursor = $db_pool->{$key}->db_cursor();
                $rc = $cursor->c_get(
                    $k, $fcontent, $desc ? DB_LAST : DB_FIRST);
                if ($rc == DB_NOTFOUND or $rc == DB_KEYEMPTY) {
                    $cursor->c_close();
                    return [];
                }
                if (defined $offset and $offset > 0) {
                    OFFSET:
                    for (my $i = 0; $rc == 0 or $rc == DB_KEYEMPTY; 
                         $rc = $cursor->c_get($k, $fcontent, 
                                              $desc ? DB_PREV :
                                                DB_NEXT)
                     ) {
                        last OFFSET if $i == $offset;
                        $i++ if $rc == 0;
                    }
                }
                my $ret = [];
                FETCH:
                for (my $i = 0; $rc == 0 or $rc == DB_KEYEMPTY; 
                     $rc = $cursor->c_get(
                         $k, $fcontent, $desc ? DB_PREV : DB_NEXT)) {
                    last FETCH if $i == $n;
                    if ($rc == 0) {
                        my $entry = {
                            KEY     => $k,
                            CONTENT => thaw($fcontent),
                        };
                        push @$ret, $entry;
                        $i++;
                    }
                }
                $cursor->c_close();
                return $ret;
            };
            
            *$count = sub {
                my $key = $makekey->($i);
                my $stat = $db_pool->{$key}->db_stat();
                if (exists $DB->{$i}->{TYPE} and 
                      $DB->{$i}->{TYPE} eq 'Hash') {
                    return $stat->{hash_ndata};
                }
                else {
                    return $stat->{bt_ndata};
                }
            };
            
            *$dels = sub {
                my ( $self, @n ) = @_;
                return 0 if @n == 0;
                my $key = $makekey->($i);
                my $deleted = 0;
                # validate $lock
                my $lock;
                my $retry = 0;
                LOCK:
                {
                    $lock = $db_pool->{$key}->cds_lock();
                    last LOCK if defined $lock;
                    sleep 3;
                    redo LOCK if ++$retry < $LOCK_RETRY_MAX;
                }
                unless (defined $lock) {
                    return ELCK;
                }
                foreach my $recno (@n) {
                    if ($db_pool->{$key}->db_del($recno) == 0) {
                        $deleted++;
                    }
                }
                $db_pool->{$key}->db_sync();
                $lock->cds_unlock();
                return $deleted;
            };
        }
        else {
            # index database(s)
            foreach my $j (0 .. $#{$DB->{$i}->{SUBS}}) {
                ( my $p = $i ) =~ s/_INDEX$//o;
                my $get = 'get_'. lc($p). 
                  's_by_'. lc($DB->{$i}->{SUBS}->[$j]);
                my $cat = 'cat_'. lc($i). '_'. lc($DB->{$i}->{SUBS}->[$j]). 
                  's';
                my $count =
                  '__'. lc($i). '_'. lc($DB->{$i}->{SUBS}->[$j]). 's';
                my $countdup = 
                  '__'. lc($i). '_'. lc($DB->{$i}->{SUBS}->[$j]). '_dups';
                
                $STUBS->{$p}->{FIELDS}->{lc($DB->{$i}->{SUBS}->[$j])} = 
                  sub { __PACKAGE__->$get(@_); };
                $STUBS->{$i}->{CAT}->{lc($DB->{$i}->{SUBS}->[$j])}
                  = sub { __PACKAGE__->$cat(@_); };
                $STUBS->{$i}->{COUNT}->{lc($DB->{$i}->{SUBS}->[$j])} = 
                  sub { __PACKAGE__->$count(@_); };
                $STUBS->{$i}->{COUNTDUP}->{lc($DB->{$i}->{SUBS}->[$j])}
                  = sub { __PACKAGE__->$countdup(@_); };

                *$get = sub {
                    # FIXME ugly api..
                    # TODO hash param
                    my ( $self, $k, $returnValue, $lastone, 
                         $n, $offset ) = @_;
                    $returnValue ||= 0;
                    croak("undefined key: $k") unless defined $k;
                    return [] if defined $n and $n <= 0;
                    my $key = $makekey->($i, $DB->{$i}->{SUBS}->[$j]);
                    #print "key = ", $key, "\n";
                    my ( $rc, $pk, $v );
                    my $ret = [];
                    
                    $pk = -1;
                    #$rc = $db_pool->{$key}->db_pget($k, $pk, $v);
                    #if ($rc == DB_NOTFOUND or $rc == DB_KEYEMPTY) {
                    #    return $ret;
                    #}
                    my $cursor = $db_pool->{$key}->db_cursor();
                    #print STDERR "status: ", $db_pool->{$key}->status(),
                    #  "\n";
                    # set cursor to begin of $k slot
                    $rc = $cursor->c_pget($k, $pk, $v, DB_SET);
                    if ($rc == DB_SECONDARY_BAD) {
                        $cursor->c_close();
                        croak("bad secondary index found");
                    }
                    if ($rc == DB_KEYEMPTY or $rc == DB_NOTFOUND) {
                        $cursor->c_close();
                        return $ret;
                    }
                    my $dup_count = 0;
                    $rc = $cursor->c_count($dup_count);
                    unless ($rc == 0) {
                        $cursor->c_close();
                        croak("cannot count duplicate keys");
                    }
                    # offset out of range
                    return $ret if defined $offset and 
                      $offset < 0 and -$offset >= $dup_count;
                    
                    if ($n and defined $offset) {
                        # splice
                        if ($offset >= 0) {
                            if ($offset > 0) {
                                OFFSET:
                                for (my $i = 0; $rc == 0; 
                                     $rc = $cursor->c_pget(
                                         $k, $pk, $v, DB_NEXT_DUP)) {
                                    last OFFSET if $i == $offset;
                                    $i++;
                                }
                            }
                            my $i = 0;
                            FETCH: 
                            {
                                last FETCH if $i == $n;
                                if ($BerkeleyDB::VERSION < 0.29) {
                                # Bug fix for BerkeleyDB v0.27
                                    $pk = unpack("L", $pk) - 1;
                                }
                                if ($returnValue) {
                                    my $entry = {
                                        KEY     => $pk,
                                        CONTENT => thaw($v),
                                    };
                                    push @$ret, $entry;
                                } else {
                                    push @$ret, $pk;
                                }
                                $i++;
                                $pk = -1;
                                redo FETCH if $cursor->c_pget(
                                    $k, $pk, $v, DB_NEXT_DUP) == 0;
                            }
                        }
                        else {
                            # $offset < 0
                            my ( $start_index, $end_index );
                            if ($n >= $dup_count+$offset) {
                                $start_index = 0;
                                $end_index = $dup_count+$offset;
                            }
                            else {
                                $end_index = $dup_count+$offset+1;
                                $start_index = $end_index-$n;
                            }
                            if ($start_index > 0) {
                                OFFSET:
                                for (my $i = 0; $rc == 0; 
                                     $rc = $cursor->c_pget(
                                         $k, $pk, $v, DB_NEXT_DUP)) {
                                    last OFFSET if $i++ == $start_index;
                                }
                            }
                            my $i = $start_index;
                            FETCH: 
                            {
                                last FETCH if $i > $end_index;
                                if ($BerkeleyDB::VERSION < 0.29) {
                                    # Bug fix for BerkeleyDB v0.27
                                    $pk = unpack("L", $pk) - 1;
                                }
                                if ($returnValue) {
                                    my $entry = { 
                                        KEY     => $pk,
                                        CONTENT => thaw($v),
                                    };
                                    push @$ret, $entry;
                                }
                                else {
                                    push @$ret, $pk;
                                }
                                $i++;
                                $pk = -1;
                                redo FETCH if $cursor->c_pget(
                                    $k, $pk, $v, DB_NEXT_DUP) == 0;
                            }
                        }
                        return $ret;
                    }
                    else {
                        my $last;
                        FETCH: 
                        {
                            if ($BerkeleyDB::VERSION < 0.29) {
                                # Bug fix for BerkeleyDB v0.27
                                $pk = unpack("L", $pk) - 1;
                            }
                            my $entry;
                            if ($returnValue) {
                                $entry = {
                                    KEY     => $pk,
                                    CONTENT => thaw($v),
                                };
                                push @$ret, $entry;
                            } else {
                                push @$ret, $pk;
                            }
                            $last = $entry;
                            $pk = -1;
                            redo FETCH if $cursor->c_pget(
                                $k, $pk, $v, DB_NEXT_DUP) == 0;
                        }
                        $cursor->c_close();
                        if (not $lastone) {
                            return $ret;
                        } else {
                            return [ $last ];
                        }
                    }
                    # NOREACH
                };
                
                *$cat = sub {
                    my ( $self, $value ) = @_;
                    my $key = $makekey->($i, $DB->{$i}->{SUBS}->[$j]);
                    #print STDERR
                    #  'database:'. $DB->{$i}->{SUBS}->[$j]. "\n";
                    my $cursor = $db_pool->{$key}->db_cursor();
                    
                    my $ret = {};
                    my ( $k, $pk, $v );
                    $k = $pk = -1;
                    $v = '';
                    # FIXME db_stat first to get key count
                    while ($cursor->c_pget(
                        $k, $pk, $v, DB_NEXT) == 0) {
                        if ($BerkeleyDB::VERSION < 0.29) {
                            # Bug fix for BerkeleyDB v0.27
                            $pk = unpack("L", $pk) - 1;
                            #print STDERR 'length of key:'. length($k). "\n";
                        }
                        if ($value) {
                            push @{$ret->{$k}}, { 
                                KEY     => $pk,
                                CONTENT => thaw($v),
                            };
                        }
                        else {
                            push @{$ret->{$k}}, $pk;
                        }
                        $k = $pk = -1;
                        $v = '';
                    }
                    $cursor->c_close();
                    return $ret;
                };
                
                *$count = sub {
                    my $key = $makekey->($i, $DB->{$i}->{SUBS}->[$j]);
                    my $stat = $db_pool->{$key}->db_stat();
                    return $stat->{bt_ndata};
                };

                *$countdup = sub {
                    my ( $self, $k) = @_;
                    croak("undefined key: $k") unless defined $k;
                    my $key = $makekey->($i, $DB->{$i}->{SUBS}->[$j]);
                    #print "key = ", $key, "\n";
                    my ( $rc, $pk, $v );
                    my $ret;
                    
                    $pk = -1;
                    #$rc = $db_pool->{$key}->db_pget($k, $pk, $v);
                    #if ($rc == DB_NOTFOUND or $rc == DB_KEYEMPTY) {
                    #    return EDUP;
                    #}
                    my $cursor = $db_pool->{$key}->db_cursor();
                    #print STDERR "status: ", $db_pool->{$key}->status(),
                    #  "\n";
                    # set cursor to begin of $k slot
                    $rc = $cursor->c_pget($k, $pk, $v, DB_SET);
                    if ($rc == DB_SECONDARY_BAD) {
                        $cursor->c_close();
                        croak("bad secondary index found");
                    }
                    if ($rc == DB_KEYEMPTY or $rc == DB_NOTFOUND) {
                        $cursor->c_close();
                        return 0;
                    }
                    $ret = EDUP;
                    $rc = $cursor->c_count($ret);
                    $cursor->c_close();
                    return $rc == 0 ? $ret : EDUP;
                };
                
            }
        }
    }
    my $stubs = '_stubs';
    *$stubs = sub() { $STUBS; };
    use strict 'refs';
    # DIRTY CODE END
}

1;
__END__

=head1 NAME

BerkeleyDB::SecIndices::Accessor - Simply drive your BerkeleyDB
database with secondary indices

=head1 SYNOPSIS

  use BerkeleyDB::SecIndices::Accessor qw(EGET ELCK EPUT EUPD);
  
  my $student = [];
  push @$student, {
    NAME  => 'tom', 
    CLASS => 'one',
    GRADE => 'two',
    SCORE => 80,
  };
  push @$student, {
    NAME  => 'jerry', 
    CLASS => 'two',
    GRADE => 'two',
    SCORE => 75,
  };
  my $stubs = BerkeleyDB::SecIndices::Accessor::->_stubs;
  foreach (@$student) {
    my $rc = $stubs->{STUDENT}->{PUT}->($_);
    die "cannot put record into database STUDENT" 
      if $rc == EPUT or $rc == ELCK;
  }
  
  my $count = $stubs->{STUDENT}->{COUNT}->();
  print "so far we have $count record(s)\n";

  $student = $stubs->{STUDENT}->{GETS}->($count);
  foreach my $s (@$student) {
    print "recno: ", $s->{KEY}, "\n";
    print "name : ", $s->{CONTENT}->{NAME}, "\n";
    print "score: ", $s->{CONTENT}->{SCORE}, "\n";
  }

  $student = $stubs->{STUDENT}->{FIELDS}->{grade}->('two', 1);
  foreach my $s (@$student) {
    $s->{CONTENT}->{GRADE} = 'three';
    my $rc = $stubs->{STUDENT}->{UPD}->(
      $s->{KEY}, $s->{CONTENT});
    die "cannot update record in database STUDENT" 
      if $rc == EUPD or $rc == ELCK;
  }
  
  my $number = $stubs->{STUDENT_INDEX}->{COUNTDUP}->{class}->('one');
  print "we have $number students in class one\n";

=head1 DESCRIPTION

BerkeleyDB is one of the most famous flat/non-relational databases
widely used. Depending on the very strong features offerred, one can
implement fast cache, in-memory/embedded database, btree, queue and
vice versa. Smart guys from both sleepycat and open-source world are
working very hard to bring new wonderful stuff. 

Here you are touching another great feature of BerkeleyDB - Secondary
Indicies. One can create several secondary databases for index
purpose. 

A typical scenario is showed in code example above. The primary
database whose name here is 'STUDENT' is associated with several
secondary indicies. The index database's name, for instance, is one of
the keys in primary database hash record. The hash constructs a table
logically, thus one index database catches and groups all values of a
specific table column. Later one can directly fetch record(s) from
primary database or in-directly perform a match action via querying
secondary index database.

=head2 WHY BerkeleyDB, WHAT ABOUT TRANSACTION, LOG and LOCK HERE

SQL-statement is mining nearly everything nowadays, indeed. 
For the data set which is access-performance-critical, stable,
by-query-and-reference-mainly, of-short-length-record-type,
non-table-join-demand, BerkeleyDB gains a stage. 

In most databases one have to talk with database locker(s) here and
there. The case is not so often this time, by introducing another
feature of BerkeleyDB - Concurrent Access Mode. The database working
under this mode, is nearly dead-lock-free. Refer to document 
on Sleepycat in case to know more about this.

=head2 DATABASE CONFIGURATION

One configuration file is required by this wheel, which is of YAML
format. The path of that file is specified by
$BerkeleyDB::SecIndices::Accessor::CONFIG.

B<Note:> DO init this value in the BEGIN section of your code before
using this module, since it will be fetched during compile-time,
_NOT_ run-time. Refer to test case(s) attached.

Say, to write a configuration file for the code example above, the
content should be:

#### database configuration begin ####

---
HOME: /path/to/your/database/home

DATABASE:

  STUDENT:

    FILE: student.db

  STUDENT_INDEX:

    FILE: indices_student.db

    SUBS: 

      - NAME

      - CLASS

      - GRADE

      - SCORE

#### database configuration end ####

As seen, this configuration file tells the module to create two db
files. The primary database is named 'STUDENT', and allocated file
name should be student.db, which will be created under the path
introduced by param 'set_data_dir' in DB_CONFIG found under the
directory specified by key 'HOME'. 

The naming rule of secondary index databases is the name of primary
database plus '_INDEX'. There will possibly be more than one database
created within this file. Yeah, BerkeleyDB supports that. Each item in
'SUBS' leads to a secondary index database created. As you can guess,
once you put a key/value in primary database, each secondary index
database will created a key/value pair, the key will be something like
$entry->{NAME}, its value will be the key of this record in primary
database. In case $entry->{NAME} is a ref of ARRAY or HASH, a
subroutine is required to extract/make desired index key, refer to
next section on how to install your customized key extractor.

By default, the module will die unless it cannot found the key slot in
hash to put into primary database.

Next, a DB_CONFIG file is required under the directory specified by
'HOME' key in configuration file. A sample content of this file:

#### DB_CONFIG start ####

set_data_dir       /path/to/create/.db/files

set_shm_key        20

#### DB_CONFIG end ####

set_data_dir specifies the path to create all *.db files. Since
DB_CONFIG is put under 'HOME', the path could be relative;

set_shm_key specifies the shared memory key. BerkeleyDB will create a
shared memory entry in system shared memory for sharing the same
database environment(lock/sync) among several working processes.

Refer to document on sleepycat for more detail.

=head2 INSTALL CALLBACKS

BerkeleyDB supports four known types of database - Btree, Hash, Recno
and Queue. 

A primary database is by default of Recno type. A 'TYPE' key can be
specified in database configuration file for the primary
database. Currently only support Btree/Hash/Recno. The module will
honor this setting. The feature is openned in case a standalone
database, which is of type Btree or Hash, is required. The database
permits duplicate key by default, DO NOT create any index database
upon it unless you know what you are doing. 

For index database, it will be B<ALWAYS> a Btree. Duplicate key is
okay. 

There are three callbacks available: C< $CB_EXTRACT_SECKEY $CB_DUP
$CB_DUPSORT >. By asigning the code ref to a callback, one can:

C< $CB_EXTRACT_SECKEY >: customize the way of extracting/making index
key for _ALL_ index database

C< $CB_DUP >           : customize the way of sorting keys in _ALL_
index database

C< $CB_DUP_SORT >      : customize the way of sorting duplicate keys
in _ALL_ index database.

B<Caution:> install the callback(s) in BEGIN section of your code. In
case one indeed wants to initialize all module-scope variables in
run-time of code, he has to postpone the load of module by C< eval
"use BerkeleyDB::SecIndices::Accessor;"; > while this way is not
recommended. 

B<Note:> a standalone Btree/Hash database mentioned above is left
untouched by _ALL_ the callbacks.

=head1 METHOD

Several subroutines are imported automatically during the load of
module. Normal way of invoking _ALL_ subs is pretty simple. As shown
above, fetch from the hash reference returned by
C<< BerkeleyDB::SecIndices::Accessor::->_stubs >>.

Each subroutine has a explicitly exported name also.

=item ___dbenv

A special subroutine to return db environment handler. Normally not
required. 

C<< BerkeleyDB::SecIndices::Accessor::->___dbenv >>

B<Note:> not covered by _stubs

=item _student and _student_index

For each database declared in configuration file, module will generate
a subroutine to fetch the database handler for invoking other
berkeleydb database methods not covered. 

Naming rule is C<< '_'. lc(<database_name>) >>

C<< BerkeleyDB::SecIndices::Accessor::->_student >>

B<Note:> not covered by _stubs

=item _stubs

a fundamental subroutine to access all 'userspace' methods
offerred. See items below.

C<< BerkeleyDB::SecIndices::Accessor::->_stubs >>

=item put_student(LIST)

For each primary database declared as type of Recno in configuration
file, module will generate a subroutine to put new HASH records into
database. As mentioned above, this will lead to a new index record
created in each secondary index database.

C<< BerkeleyDB::SecIndices::Accessor::->put_student->(@entries) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{PUT}->(@entries)
>> 

return the first new key on success, EPUT or ELCK on failure.

=item PUT method for standalone Btree/Hash database

For each standalone Btree/Hash database declared in configuration file,
module will generate a subroutine to put new key/value into database.

C<< BerkeleyDB::SecIndices::Accessor::->put_<lc(dbname)>->($key,
$entry) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{dbname}->{PUT}->($key,
$entry) >> 

return TRUE on success, EPUT or ELCK on failure.

=item put2_student(\@hash_values, \@new_keys)

For each primary database declared as type of Recno in configuration
file, module will generate a subroutine to put new HASH records into
database. This will lead to a new index record created in each
secondary index database.

C<< BerkeleyDB::SecIndices::Accessor::->_put2_student(\@entries,
\@keys) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{PUT2}->(\@entries,
\@keys) >>

return TRUE on success, EPUT or ELCK on failure.
The keys of new created records will be filled in C<< @keys >> as the
same sequence of entries in C<< @entries >>.

=item PUT2 method for standalone Btree/Hash database

For each standalone Btree/Hash database declared in configuration
file, module will generate a subroutine to put new key/value pairs
into database.

C<< BerkeleyDB::SecIndices::Accessor::->put2_<lc(dbname)>->(\%pairs,
\@keys) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{dbname}->{PUT2}->(\%pairs,
\@keys) >>

return TRUE on success, EPUT or ELCK on failure.
The keys of new created records will be filled in C<< @keys >>. 
B<Note:> Since using HASH, sequence of keys is not guaranteed.

=item upd_student($key, $entry)

For each primary database declared in configuration file, module will
generate a subroutine to update a HASH record in database. This will
also lead to specific key change in some secondary index database.

C<< BerkeleyDB::SecIndices::Accessor::->upd_student->($key, $entry) >> 

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{UPD}->($key,
$entry) >> 

return 0 on success, EUPD or ELCK on failure.

=item get_student($key)

For each primary database declared in configuration file, module will
generate a subroutine to get a HASH record in database. 

C<< BerkeleyDB::SecIndices::Accessor::->get_student->($key) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{GET}->($key)
>> 

return HASH ref of record on success, EGET EEPT or EGET on failure.

=item get_students($number, [ $is_reverse, $offset ])

For each primary database declared in configuration file, module will
generate a subroutine to get records.

in reverse order if $is_reverse is true;
from offset $offset if $offset is set.

return a ref of ARRAY which contains fetched records. 
The number of items returned is actually depended on real item count
in database.
The structure of item is C<< { KEY => $key, CONTENT => $entry } >>

C<< BerkeleyDB::SecIndices::Accessor::->get_students($number) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{GETS}->($number,
1, 20) >>

=item del_students(LIST)

For each primary database declared in configuration file, module will
generate a subroutine to delete requested record in database.

C<< BerkeleyDB::SecIndices::Accessor::->del_students(@key_list) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{DEL}->(@key_list)
>> 

return deleted item number on success, ELCK on failure.

=item __students

For each primary database declared in configuration file, module will
generate a subroutine to return current record number in database.

C<< BerkeleyDB::SecIndices::Accessor::->__students() >>

C<< BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{COUNT}->()
>> 

=item get_students_by_class($sec_key, [ $need_return_value,
$fetch_only_lastone, $number, $offset ])

For each secondary database declared in configuration file, module
will generate a subroutine to query associated primary database by
index.

$sec_key           : key of secondary index database, normally a string
for SCALAR index field;

$need_return_value : return value of primary record if true;

$fetch_only_lastone: return only the last record if true;

$number            : specify the number of record to fetch;

$offset            : specify the offset to start for $number.

$offset can be a negative value, retrieving in reverse order.

C<<
BerkeleyDB::SecIndices::Accessor::->get_students_by_class($sec_key) >> 

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{FIELDS}->{class}->($sec_key,
1) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{FIELDS}->{class}->($sec_key,
0, 1) >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT}->{FIELDS}->{class}->($sec_key,
1, undef, 20, 3) >>

return a ref of ARRAY which contains keys of fetched record. 
The structure of item is C<< { KEY => $key, CONTENT => $entry } >> if
$need_return_value is true.

Yeah, the proto is very ugly... Possibly offer a hash-style proto in
future. 

=item cat_student_index_grades([ $need_return_value ])

For each secondary database declared in configuration file, module
will generate a subroutine to fetch all current index records.

$need_return_value: return value of primary record if true.

C<< BerkeleyDB::SecIndices::Accessor::->cat_student_grades() >>

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT_INDEX}->{CAT}->{grade}->(1)
>> 

return a ref of ARRAY which contains key/value pairs of fetched
record. Recall that the record value in secondary index database is
the key of associated record in primary database. 
The structure of value for each key is C<< { KEY => $key, CONTENT =>
$primary_entry } >> if $need_return_value is true.

=item __student_index_scores

For each secondary database declared in configuration file, module
will generate a subroutine to return current record number in
database. 

C<< BerkeleyDB::SecIndices::Accessor::->__student_scores() >> 

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT_INDEX}->{COUNT}->{score}->()
>> 

=item __student_index_score_dups($sec_key)

For each secondary database declared in configuration file, module
will generate a subroutine to return current duplicate record number
of requested $sec_key in database.

C<< BerkeleyDB::SecIndices::Accessor::->_student_score_dups($sec_key)
>> 

C<<
BerkeleyDB::SecIndices::Accessor::->_stubs->{STUDENT_INDEX}->{COUNTDUP}->{score}->($sec_key)
>> 

=head2 Error Checking

EPUT: error on creating new record(s);

EUPD: error on updating record;

EGET: error on fetching record;

EEPT: no record found or record deleted for requested key;

EGTS: error on fetching records;

EDEL: error on deleting record(s);

ELCK: error on obtaining a database cocurrent lock.

B<CAUTION:> _ALL_ subroutines related to secondary index database will
croak in case the index database corrupted. 

=head2 EXPORT

EGET EPUT EDEL ELCK ... TRUE

Export _ALL_ operation check flags by C< use
BerkeleyDB::SecIndices::Accessor qw(:const) >

=head1 CAVEAT

Refer to document on Sleepycat regarding database backup/recovery and
upgrade. 

=head1 BUG

_ALL_ error check flags is integer. Once the returned value of
subroutine is a reference or string, such code C<< $ret == EGET >>
will get a warning message. 

B<NO BerkeleyDB::Queue support>.

=head1 TODO

Traditional transaction mode support.

UPD2 similar to PUT2.

Method to export a cursor.

BerkeleyDB::Queue support.

=head1 SEE ALSO

L<BerkeleyDB|BerkeleyDB> L<YAML|YAML> L<Storable|Storable>

L<DB_File|DB_File>

L<BerkeleyDB Home|http://www.sleepycat.com>

=head1 AUTHOR

Dongxu Ma, E<lt>dongxu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

For your working copy of BerkeleyDB, normally it is under
Sleepycat open source license, refer to
http://www.sleepycat.com/company/licensing.html for detail.

=cut
