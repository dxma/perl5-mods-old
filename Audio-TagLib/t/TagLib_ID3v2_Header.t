# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_ID3v2_Header.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More q(no_plan);
#use Test::More tests => 1;
BEGIN { use_ok('Audio::TagLib::ID3v2::Header') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY majorVersion revisionNumber
unsynchronisation extendedHeader experimentalIndicator footerPresent
tagSize completeTagSize setTagSize setData render size fileIdentifier);
can_ok("Audio::TagLib::ID3v2::Header", @methods) 							or
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v2::Header->new();
my $data = Audio::TagLib::ByteVector->new("blah blah");
my $j = Audio::TagLib::ID3v2::Header->new($data);
isa_ok($i, "Audio::TagLib::ID3v2::Header") 								or
	diag("method new() failed");
isa_ok($j, "Audio::TagLib::ID3v2::Header") 								or
	diag("method new(bytevector) failed");

SKIP: {
skip "more test needed", 1 if 1;
ok(1);
}