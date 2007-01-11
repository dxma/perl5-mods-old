# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v2_Frame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More q(no_plan);
#use Test::More tests => 5;
BEGIN { use_ok('Audio::TagLib::ID3v2::Footer') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(DESTROY frameID size setData setText toString render
headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::Frame", @methods) 							or 
	diag("can_ok failed");

cmp_ok(Audio::TagLib::ID3v2::Frame->headerSize(), "==", 10) 				or 
	diag("method headerSize() failed");
cmp_ok(Audio::TagLib::ID3v2::Frame->headerSize(2), "==", 6) 				or 
	diag("method headerSize() failed");
cmp_ok(Audio::TagLib::ID3v2::Frame->textDelimiter("Latin1")->data(), "==", undef) or 
	diag("method textDelimiter(Latin1) failed");
SKIP: {
skip "more test needed", 1 if 1;
ok(1);
}