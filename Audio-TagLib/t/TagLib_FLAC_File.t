# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_FLAC_File.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
#use Test::More tests => 11;
use Test::More skip_all => "flac file too large to be attached with";
BEGIN { use_ok('Audio::TagLib::FLAC::File') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY ID3v2Tag ID3v1Tag xiphComment
setID3v2FrameFactory streamInfoData streamLength name tag
audioProperties save readBlock writeBlock find rfind insert
removeBlock readOnly isOpen isValid seek clear tell length );
can_ok("Audio::TagLib::FLAC::File", @methods) 							or 
	diag("can_ok failed");

my $file = "sample/Discontent.flac";
my $i = Audio::TagLib::FLAC::File->new($file);
isa_ok($i, "Audio::TagLib::FLAC::File") 								or 
	diag("method new(file) failed");
isa_ok($i->tag(), "Audio::TagLib::Tag") 								or 
	diag("method tag() failed");
isa_ok($i->audioProperties(), "Audio::TagLib::FLAC::Properties") 		or 
	diag("method audioProperties() failed");
isa_ok($i->ID3v2Tag(1), "Audio::TagLib::ID3v2::Tag") 					or 
	diag("method ID3v2Tag(t) failed");
isa_ok($i->ID3v1Tag(1), "Audio::TagLib::ID3v1::Tag") 					or 
	diag("method ID3v1Tag(t) failed");
isa_ok($i->xiphComment(1), "Audio::TagLib::Ogg::XiphComment") 			or 
	diag("method xiphComment(t) failed");
$i->setID3v2FrameFactory(Audio::TagLib::ID3v2::FrameFactory->instance());
isa_ok($i->streamInfoData(), "Audio::TagLib::ByteVector") 				or 
	diag("method streamInfoData() failed");
cmp_ok($i->streamLength(), "==", 3980578) 						or 
	diag("method streamLength() failed");
SKIP: {
skip "save() skipped", 1 if 1;
ok(not $i->save()) 												or 
	diag("method save() failed");
}