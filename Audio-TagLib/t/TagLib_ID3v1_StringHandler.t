# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v1_StringHandler.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More q(no_plan);
#use Test::More tests => 1;
BEGIN { use_ok('Audio::TagLib::ID3v1::StringHandler') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(parse render);
can_ok("Audio::TagLib::ID3v1::StringHandler", @methods) 					or 
	diag("can_ok failed");

TODO: {
local $TODO = "more test needed";
}
