# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_File.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 16;
BEGIN { use_ok('Audio::TagLib::File') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(DESTROY name tag audioProperties save readBlock
writeBlock find rfind insert removeBlock readOnly isOpen isValid seek
clear tell length );
can_ok("Audio::TagLib::File", @methods) 								or
	diag("can_ok failed");

my $file = "sample/Discontent.mp3";
my $fileref = Audio::TagLib::FileRef->new($file);
my $i = $fileref->file();
is($i->name(), $file) 											or
	diag("method name() failed");
SKIP: {
skip "pure virtual methods", 3 if 1;
isa_ok($i->tag(), "Audio::TagLib::Tag") 								or
	diag("method tag() failed");
isa_ok($i->audioProperties(), "Audio::TagLib::AudioProperties") 		or
	diag("method audioProperties() failed");
ok($i->save()) 													or
	diag("method save() failed");
}
my $blocksize = 1024;
cmp_ok($i->readBlock($blocksize)->size(), "==", $blocksize) 	or
	diag("method readBlock(blocksize) failed");
SKIP: {
skip "methods qw(writeBlock insert removeBlock clear)", 0 if 1;
}
cmp_ok($i->find(Audio::TagLib::ByteVector->new("4")), "==", 1255) 		or
	diag("method find(pattern) failed");
$i->seek(0, "End");
cmp_ok($i->tell(), "==", $i->length()) 							or
	diag("method seek() and length() failed");
cmp_ok($i->rfind(Audio::TagLib::ByteVector->new("4"), 20), "==", -1) 	or
	diag("method rfind(pattern, fromOffset) failed");
SKIP: {
skip "readOnly() skipped", 1 if 1;
ok($i->readOnly()) 												or
	diag("method readOnly() failed");
}
ok($i->isOpen()) 												or
	diag("method isOpen() failed");
ok($i->isValid()) 												or
	diag("method isValid() failed");
$i->seek(0);
cmp_ok($i->tell(), "==", 0) 									or
	diag("method seek() and tell() failed");

ok(Audio::TagLib::File->isReadable(__FILE__))							or
	diag("method isReadable(file) failed");
ok(Audio::TagLib::File->isWritable(__FILE__)) 							or
	diag("method isWritable(name) failed");
