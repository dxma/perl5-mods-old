# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl BerkeleyDB-SecIndices-Accessor.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More tests => 1;
use Test::More qw(no_plan);

our ( $tmphome, $tmpconf );

BEGIN {
	use File::Temp qw(tempdir);
	$tmphome = tempdir( CLEANUP => 1 );
	die "cannot find a temp directory for testing" unless -d $tmphome;

	require File::Spec;
    $tmpconf = File::Spec::->catfile($tmphome, 'dbconfig.yml');
	open my $h1, ">", $tmpconf
      or die "cannot create temp configuration file for testing";
	print $h1 <<"EOF1";
---
HOME: $tmphome
DATABASE:
  STUDENT:
    FILE: student.db
  STUDENT_INDEX:
    FILE: indicies_student.db
    SUBS:
      - NAME
      - CLASS
      - GRADE
      - SCORE
EOF1
	close $h1;
	open $h1, ">", File::Spec::->catfile($tmphome, 'DB_CONFIG')
	  or die "cannot create temp DB_CONFIG for testing";
	print $h1 <<"EOF2";
set_data_dir    $tmphome
set_shm_key     30
EOF2
	close $h1;

	$BerkeleyDB::SecIndices::Accessor::CONFIG = $tmpconf;
}

END {
    eval {
        my $_env = BerkeleyDB::SecIndices::Accessor::->___dbenv;
        if (defined $_env) {
            &BerkeleyDB::env_remove(Home => $tmphome);
        }
    };
}

use_ok('BerkeleyDB::SecIndices::Accessor');
eval { use BerkeleyDB::SecIndices::Accessor qw(:const); };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# interface check first
my @methods = (qw(___dbenv _student _student_index_name
                 _student_index_class _student_index_grade
                 _student_index_score _stubs put_student
                 upd_student get_student get_students __students
                 del_students get_students_by_name
                 get_students_by_class get_students_by_grade
                 get_students_by_score cat_student_index_names
                 cat_student_index_classs cat_student_index_grades
                 cat_student_index_scores __student_index_names
                 __student_index_classs __student_index_grades
                 __student_index_scores __student_index_name_dups
                 __student_index_class_dups __student_index_grade_dups
                 __student_index_score_dups put2_student));
can_ok('BerkeleyDB::SecIndices::Accessor', @methods);

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
ok( ref $stubs eq 'HASH' );

foreach (@$student) {
    my $rc = $stubs->{STUDENT}->{PUT}->($_);
    ok( $rc ne EPUT and $rc ne ELCK );
}

my $count = $stubs->{STUDENT}->{COUNT}->();
is( $count, scalar(@$student) );

my $student_db = $stubs->{STUDENT}->{GETS}->($count);
foreach my $i (0 .. $#{$student_db}) {
    foreach my $f (qw(NAME CLASS GRADE SCORE)) {
        is( $student_db->[$i]->{CONTENT}->{$f},
            $student->[$i]->{$f} );
    }
}

$student = $stubs->{STUDENT}->{FIELDS}->{grade}->('two', 1);
foreach my $s (@$student) {
    $s->{CONTENT}->{GRADE} = 'three';
    my $rc = $stubs->{STUDENT}->{UPD}->(
        $s->{KEY}, $s->{CONTENT});
    ok( $rc ne EUPD or $rc ne ELCK );
}

my $number = $stubs->{STUDENT_INDEX}->{COUNT}->{score}->();
cmp_ok( $number, '==', 2 );

$number = $stubs->{STUDENT_INDEX}->{COUNTDUP}->{grade}->('two');
cmp_ok( $number, '==', 0 );

$student = $stubs->{STUDENT}->{FIELDS}->{score}->(80, 1);
is( $student->[0]->{CONTENT}->{NAME}, 'tom' );
