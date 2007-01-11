# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_MPC_File.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 8;
BEGIN { use_ok('Audio::TagLib::MPC::File') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY ID3v1Tag APETag remove name tag
audioProperties save readBlock writeBlock find rfind insert
removeBlock readOnly isOpen isValid seek clear tell length );
can_ok("Audio::TagLib::MPC::File", @methods) 							or 
	diag("can_ok failed");

my $file = "sample/Discontent.mp3";
my $i = Audio::TagLib::MPC::File->new($file);
isa_ok($i, "Audio::TagLib::MPC::File") 								or 
	diag("method new(file) failed");
isa_ok($i->tag(), "Audio::TagLib::Tag") 								or 
	diag("method tag() failed");
isa_ok($i->audioProperties(), "Audio::TagLib::MPC::Properties") 		or 
	diag("method audioProperties() failed");
isa_ok($i->ID3v1Tag(1), "Audio::TagLib::ID3v1::Tag") 					or 
	diag("method ID3v1Tag(t) failed");
isa_ok($i->APETag(1), "Audio::TagLib::APE::Tag") 						or 
	diag("method APETag(t) failed");
SKIP: {
skip "save() skipped", 1 if 1;
ok(not $i->save()) 												or 
	diag("method save() failed");
}
