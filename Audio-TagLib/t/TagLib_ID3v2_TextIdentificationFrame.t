# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v2_TextIdentificationFrame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 7;
BEGIN { use_ok('Audio::TagLib::ID3v2::TextIdentificationFrame') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY toString setText textEncoding
setTextEncoding fieldList frameID size setData setText render
headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::TextIdentificationFrame", @methods) 			or 
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v2::TextIdentificationFrame->new(
	Audio::TagLib::ByteVector->new(), "UTF8");
isa_ok($i, "Audio::TagLib::ID3v2::TextIdentificationFrame") 				or 
	diag("method new(type, encoding) failed");
$i->setText(Audio::TagLib::String->new("blah blah"));
is($i->toString()->toCString(), "blah blah") 						or 
	diag("method setText(s) and toString() failed");
$i->setText(Audio::TagLib::StringList->new(Audio::TagLib::String->new("blah blah blah")));
is($i->toString()->toCString(), "blah blah blah") 					or 
	diag("method setText(l) failed");
$i->setTextEncoding("UTF16BE");
is($i->textEncoding(), "UTF16BE") 									or 
	diag("method setTextEncoding(t) and textEncoding() failed");
isa_ok($i->fieldList(), "Audio::TagLib::StringList") 						or 
	diag("method fieldList() failed");
