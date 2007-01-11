# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v1_Tag.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 14;
BEGIN { use_ok('Audio::TagLib::ID3v1::Tag') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY render title artist album comment genre
year track setTitle setArtist setAlbum setComment setGenre setYear
setTrack fileIdentifier setStringHandler);
can_ok("Audio::TagLib::ID3v1::Tag", @methods) 			or 
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v1::Tag->new();
isa_ok($i, "Audio::TagLib::ID3v1::Tag") 				or 
	diag("method new() failed");
SKIP: {
skip "current no test for new(file, tagOffset)", 1 if 1;
my $file = "dummy";
my $tagOffset = 0;
my $j = Audio::TagLib::ID3v1::Tag->new(Audio::TagLib::File->new($file), $tagOffset);
isa_ok($j, "Audio::TagLib::ID3v1::Tag") 				or 
	diag("method new(file, tagOffset) failed");
}

$i->setTitle(Audio::TagLib::String->new("Title"));
is($i->title()->toCString(), "Title") 			or 
	diag("method setTitle(string) and title() failed");
$i->setArtist(Audio::TagLib::String->new("Artist"));
is($i->artist()->toCString(), "Artist") 		or 
	diag("method setArtist(string) and artist() failed");
$i->setAlbum(Audio::TagLib::String->new("Album"));
is($i->album()->toCString(), "Album") 			or 
	diag("method setAlbum(string) and album() failed");
$i->setComment(Audio::TagLib::String->new("Comment"));
is($i->comment()->toCString(), "Comment") 		or 
	diag("method setComment(string) and comment() failed");
$i->setGenre(Audio::TagLib::String->new("Classic Rock"));
is($i->genre()->toCString(), "Classic Rock") 	or 
	diag("method setGenre(string) and genre() failed");
$i->setYear(1981);
cmp_ok($i->year(), "==", 1981) 					or 
	diag("method setYear(uint) and year() failed");
$i->setTrack(3);
cmp_ok($i->track(), "==", 3) 					or 
	diag("method setTrack(uint) and track() failed");

isa_ok($i->render(), "Audio::TagLib::ByteVector") 		or 
	diag("method render() failed");
is(Audio::TagLib::ID3v1::Tag->fileIdentifier()->data(), "TAG") or 
	diag("method fileIdentifier() failed");
SKIP : {
skip "no test possible for setStringHandler(handler)", 1 if 1;
ok(Audio::TagLib::ID3v1::Tag->setStringHandler());
}
