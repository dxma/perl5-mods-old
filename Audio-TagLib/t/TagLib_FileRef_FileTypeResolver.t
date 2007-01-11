# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_FileRef_FileTypeResolver.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Audio::TagLib::FileRef::FileTypeResolver') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(createFile);
can_ok("Audio::TagLib::FileRef::FileTypeResolver", @methods) 			or 
	diag("can_ok failed");
