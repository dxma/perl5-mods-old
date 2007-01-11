# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_MPEG_Header.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More q(no_plan);
#use Test::More tests => 1;
BEGIN { use_ok('Audio::TagLib::MPEG::Header') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY isValid version layer protectionEnabled
bitrate sampleRate isPadded channelMode isCopyrighted isOriginal
frameLength copy);
can_ok("Audio::TagLib::MPEG::Header", @methods) 					or 
	diag("can_ok failed");

SKIP: {
skip "more test needed", 1 if 1;
ok(1);
}
