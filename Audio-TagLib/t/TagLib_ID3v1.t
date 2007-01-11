# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 6;
BEGIN { use_ok('Audio::TagLib::ID3v1') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(genreList genreMap genre genreIndex);
can_ok("Audio::TagLib::ID3v1", @methods) 								or 
	diag("can_ok failed");

isa_ok(Audio::TagLib::ID3v1->genreList(), "Audio::TagLib::StringList") 		or 
	diag("method genreList() failed");
isa_ok(Audio::TagLib::ID3v1->genreMap(), "Audio::TagLib::ID3v1::GenreMap") 	or 
	diag("method genreMap() failed");
is(Audio::TagLib::ID3v1->genre(1)->toCString(), "Classic Rock") 		or 
	diag("method genre(index) failed");
cmp_ok(Audio::TagLib::ID3v1->genreIndex(Audio::TagLib::String->new("Classic Rock")),
	"==", 1) or diag("method genreIndex(name) failed");