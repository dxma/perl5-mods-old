# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v2_AttachedPictureFrame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 10;
BEGIN { use_ok('Audio::TagLib::ID3v2::AttachedPictureFrame') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY toString textEncoding setTextEncoding
mimeType setMimeType type setType description setDescription picture
setPicture frameID size setData setText render headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::AttachedPictureFrame", @methods) 			or 
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v2::AttachedPictureFrame->new();
isa_ok($i, "Audio::TagLib::ID3v2::AttachedPictureFrame") 					or 
	diag("method new() failed");
$i->setTextEncoding("UTF8");
isa_ok(Audio::TagLib::ID3v2::AttachedPictureFrame->new($i->render()), 
	"Audio::TagLib::ID3v2::AttachedPictureFrame") 							or 
	diag("method new(data) failed");

is($i->textEncoding(), "UTF8") 										or 
	diag("method setTextEncoding(encode) and textEncoding() failed");
$i->setMimeType(Audio::TagLib::String->new("image/jpeg"));
is($i->mimeType()->toCString(), "image/jpeg") 						or 
	diag("method setMimeType(t) and mimeType() failed");
$i->setType("Other");
is($i->type(), "Other") 											or 
	diag("method setType(t) and type() failed");
$i->setDescription(Audio::TagLib::String->new("description"));
is($i->description()->toCString(), "description") 					or 
	diag("method setDescription(desc) and description() failed");
is($i->toString()->toCString(), "description [image/jpeg]") 		or 
	diag("method toString() failed");
$i->setPicture(Audio::TagLib::ByteVector->new("a dummy picture"));
is($i->picture()->data(), "a dummy picture") 						or 
	diag("method setPicture(p) and picture() failed");
