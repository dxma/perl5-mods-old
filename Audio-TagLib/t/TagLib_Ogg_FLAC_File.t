# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_Ogg_FLAC_File.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More q(no_plan);
#use Test::More tests => 2;
BEGIN { use_ok('Audio::TagLib::Ogg::FLAC::File') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY streamLength packet setPacket firstPageHeader
lastPageHeader name tag audioProperties save
readBlock writeBlock find rfind insert removeBlock readOnly isOpen
isValid seek clear tell length );
can_ok("Audio::TagLib::Ogg::FLAC::File", @methods) 					or 
	diag("can_ok failed");

SKIP: {
skip "more test needed", 1 if 1;
ok(1);
}
