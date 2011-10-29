# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_ID3v2_UniqueFileIdentifierFrame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 8;
BEGIN { use_ok('Audio::TagLib::ID3v2::UniqueFileIdentifierFrame') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY owner identifier setOwner setIdentifier
toString frameID size setData setText render headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::UniqueFileIdentifierFrame", @methods) 		or
	diag("can_ok failed");

my $owner = Audio::TagLib::String->new("owner");
my $id = Audio::TagLib::ByteVector->new("id");
my $i = Audio::TagLib::ID3v2::UniqueFileIdentifierFrame->new($owner, $id);
isa_ok($i, "Audio::TagLib::ID3v2::UniqueFileIdentifierFrame") 				or
	diag("method new(owner,id) failed");
is($i->owner()->toCString(), $owner->toCString()) 					or
	diag("method owner() failed");
is($i->identifier()->data(), $id->data()) 							or
	diag("method identifier() failed");
my $newowner = Audio::TagLib::String->new("newowner");
my $newid = Audio::TagLib::ByteVector->new("newid");
$i->setOwner($newowner);
is($i->owner()->toCString(), $newowner->toCString()) 				or
	diag("method setOwner(s) failed");
$i->setIdentifier($newid);
is($i->identifier()->data(), $newid->data()) 						or
	diag("method setIdentifier(v) failed");
is($i->toString()->toCString(), "") 								or
	diag("method toString() failed");
