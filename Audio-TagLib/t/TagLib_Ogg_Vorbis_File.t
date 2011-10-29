# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_Ogg_Vorbis_File.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 5;
BEGIN { use_ok('Audio::TagLib::Ogg::Vorbis::File') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(name tag audioProperties save
readBlock writeBlock find rfind insert removeBlock readOnly isOpen
isValid seek clear tell length );
can_ok("Audio::TagLib::Ogg::Vorbis::File", @methods) 					or
	diag("can_ok failed");

my $file = "sample/Discontent.ogg";
my $i = Audio::TagLib::Ogg::Vorbis::File->new($file);
isa_ok($i, "Audio::TagLib::Ogg::Vorbis::File") 						or
	diag("method new(file) failed");
isa_ok($i->tag(), "Audio::TagLib::Ogg::XiphComment") 				or
	diag("method tag() failed");
isa_ok($i->audioProperties(), "Audio::TagLib::Ogg::Vorbis::Properties") or
	diag("method audioProperties() failed");
SKIP: {
skip "save() skipped", 0 if 1;
}
