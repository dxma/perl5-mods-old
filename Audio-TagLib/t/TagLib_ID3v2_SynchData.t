# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v2_SynchData.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 4;
BEGIN { use_ok('Audio::TagLib::ID3v2::SynchData') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(toUInt fromUInt);
can_ok("Audio::TagLib::ID3v2::SynchData", @methods) 					or 
	diag("can_ok failed");

cmp_ok(Audio::TagLib::ID3v2::SynchData->toUInt(Audio::TagLib::ByteVector->new("a")), 
	"==", 97) or diag("method toUInt(data) failed");
my $data = Audio::TagLib::ID3v2::SynchData->fromUInt(97)->data();
cmp_ok(length($data), "==", 4) 									or 
	diag("method fromUInt(value) failed");
