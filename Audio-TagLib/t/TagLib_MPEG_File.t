# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_MPEG_File.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 14;
BEGIN { use_ok('Audio::TagLib::MPEG::File') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY ID3v2Tag ID3v1Tag APETag
setID3v2FrameFactory strip firstFrameOffset nextFrameOffset
previousFrameOffset lastFrameOffset name tag audioProperties save
readBlock writeBlock find rfind insert removeBlock readOnly isOpen
isValid seek clear tell length );
can_ok("Audio::TagLib::MPEG::File", @methods) 							or 
	diag("can_ok failed");

my $file = "sample/Discontent.mp3";
my $i = Audio::TagLib::MPEG::File->new($file);
isa_ok($i, "Audio::TagLib::MPEG::File") 								or 
	diag("method new(file) failed");
isa_ok($i->tag(), "Audio::TagLib::Tag") 								or 
	diag("method tag() failed");
isa_ok($i->audioProperties(), "Audio::TagLib::MPEG::Properties") 		or 
	diag("method audioProperties() failed");
isa_ok($i->ID3v2Tag(1), "Audio::TagLib::ID3v2::Tag") 					or 
	diag("method ID3v2Tag(t) failed");
isa_ok($i->ID3v1Tag(1), "Audio::TagLib::ID3v1::Tag") 					or 
	diag("method ID3v1Tag(t) failed");
isa_ok($i->APETag(1), "Audio::TagLib::APE::Tag") 						or 
	diag("method APETag(t) failed");
$i->setID3v2FrameFactory(Audio::TagLib::ID3v2::FrameFactory->instance());
SKIP: {
skip "save() & strip(tags) skipped", 2 if 1;
ok(not $i->save()) 												or 
	diag("method save() failed");
ok(not $i->strip("APE")) 										or 
	diag("method strip(tags) failed");
}
cmp_ok($i->firstFrameOffset(), "==", 924) 						or 
	diag("method firstFrameOffset() failed");
cmp_ok($i->nextFrameOffset(925), "==", 1037) 					or 
	diag("method nextFrameOffset(p) failed");
cmp_ok($i->previousFrameOffset(544553), "==", 544502) 			or 
	diag("method previousFrameOffset(p) failed");
cmp_ok($i->lastFrameOffset(), "==", 544553) 					or 
	diag("method lastFrameOffset() failed");