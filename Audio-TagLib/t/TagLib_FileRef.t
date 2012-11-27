# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_FileRef.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 15;
BEGIN { use_ok('Audio::TagLib::FileRef') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY tag audioProperties file save isNull
copy _equal);
can_ok("Audio::TagLib::FileRef", @methods) 						or
	diag("can_ok failed");

ok(Audio::TagLib::FileRef->new()->isNull()) 						or
	diag("method new() failed");
my $file = "sample/Discontent.mp3";
my $i = Audio::TagLib::FileRef->new($file);
my $j = Audio::TagLib::FileRef->new($file, 0, "Fast");
my $File = Audio::TagLib::FileRef->create($file);
is($File->name(), $file) 									or
	diag("method create(file) failed");
my $k = Audio::TagLib::FileRef->new($File);
my $l = Audio::TagLib::FileRef->new($i);
isa_ok($i, "Audio::TagLib::FileRef") 								or
	diag("method new(file) failed");
isa_ok($j, "Audio::TagLib::FileRef") 								or
	diag("method new(file, readAudioProperties, ReadStyle) failed");
isa_ok($k, "Audio::TagLib::FileRef") 								or
	diag("method new(File *) failed");
isa_ok($l, "Audio::TagLib::FileRef") 								or
	diag("method new(FileRef) failed");
isa_ok($i->tag(), "Audio::TagLib::Tag") 							or
	diag("method tag() failed");
isa_ok($i->audioProperties(), "Audio::TagLib::AudioProperties") 	or
	diag("method audioProperties() failed");
isa_ok($i->file(), "Audio::TagLib::File") 							or
	diag("method file() failed");
SKIP: {
skip "methods qw(save copy addFileTypeResolver)", 0 if 1;
}
ok(not $i->isNull()) 										or
	diag("method isNull() failed");
ok($i == $l) 												or
	diag("method _equal(ref) failed");
ok($i != $j) 												or
	diag("method _equal(ref) failed");
is(Audio::TagLib::FileRef->defaultFileExtensions()->toString()->toCString(),
	"ogg flac mp3 mpc") 									or
	diag("method defaultFileExtensions() failed");
