# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v2_UserTextIdentificationFrame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 7;
BEGIN { use_ok('Audio::TagLib::ID3v2::UserTextIdentificationFrame') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY toString description setDescription
setText textEncoding setTextEncoding fieldList frameID size setData
render headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::UserTextIdentificationFrame", @methods) 		or 
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v2::UserTextIdentificationFrame->new();
isa_ok($i, "Audio::TagLib::ID3v2::UserTextIdentificationFrame") 			or 
	diag("method new() failed");
$i->setText(Audio::TagLib::String->new("blah blah"));
like($i->toString()->toCString(), qr(blah\sblah)) 					or 
	diag("method setText(s) and toString() failed");
$i->setText(Audio::TagLib::StringList->new(Audio::TagLib::String->new("blah blah blah")));
like($i->toString()->toCString(), qr(blah\sblah\sblah)) 			or 
	diag("method setText(l) failed");
$i->setDescription(Audio::TagLib::String->new("desc"));
is($i->description()->toCString(), "desc") 							or 
	diag("method setDescription(desc) and description() failed");
isa_ok($i->fieldList(), "Audio::TagLib::StringList") 						or 
	diag("method fieldList() failed");
TODO: {
local $TODO = "method find(Tag *tag, String &desc) not exported";
}