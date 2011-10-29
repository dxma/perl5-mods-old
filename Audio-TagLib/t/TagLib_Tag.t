# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_Tag.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Audio::TagLib::Tag') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(DESTROY title artist album comment genre year track
setTitle setArtist setAlbum setComment setGenre setYear setTrack
isEmpty );
can_ok("Audio::TagLib::Tag", @methods) 			or
	diag("can_ok failed");
