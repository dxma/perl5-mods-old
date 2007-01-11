# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v1_GenreMap_Iterator.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 8;
BEGIN { use_ok('Audio::TagLib::ID3v1::GenreMap::Iterator') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY data next last);
can_ok("Audio::TagLib::ID3v1::GenreMap::Iterator", @methods) or diag("can_ok failed");
my $genremap = Audio::TagLib::ID3v1->genreMap();
my $i = $genremap->begin();
isa_ok($i, "Audio::TagLib::ID3v1::GenreMap::Iterator") 					or 
	diag("method Audio::TagLib::ID3v1::genreMap() failed");
isa_ok(Audio::TagLib::ID3v1::GenreMap::Iterator->new(), 
	"Audio::TagLib::ID3v1::GenreMap::Iterator") 							or 
	diag("method new() failed");
isa_ok(Audio::TagLib::ID3v1::GenreMap::Iterator->new($i), 
	"Audio::TagLib::ID3v1::GenreMap::Iterator") 							or 
	diag("method new(i) failed");

cmp_ok($i->data(), "==", 123) 										or 
	diag("method data() failed");
cmp_ok($i->next()->data(), "==", 34) 								or 
	diag("method next() failed");
cmp_ok((--$i)->data(), "==", 123) 									or 
	diag("method last() failed");
