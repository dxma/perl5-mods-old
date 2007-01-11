# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_MPEG_Properties.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 11;
BEGIN { use_ok('Audio::TagLib::MPEG::Properties') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY length bitrate sampleRate channels
version layer channelMode isCopyrighted isOriginal);
# protectionEnabled not implemented in c code
can_ok("Audio::TagLib::MPEG::Properties", @methods) 					or 
	diag("can_ok failed");

my $file = "sample/Discontent.mp3";
my $mpegfile = Audio::TagLib::MPEG::File->new($file);
my $i = $mpegfile->audioProperties();
cmp_ok($i->length(), "==", 68) 									or 
	diag("method length() failed");
cmp_ok($i->bitrate(), "==", 64) 								or 
	diag("method bitrate() failed");
cmp_ok($i->sampleRate(), "==", 22050) 							or 
	diag("method sampleRate() failed");
cmp_ok($i->channels(), "==", 2) 								or 
	diag("method channels() failed");
is($i->version(), "Version2") 									or 
	diag("method version() failed");
cmp_ok($i->layer(), "==", 3) 									or 
	diag("method layer() failed");
is($i->channelMode(), "Stereo") 								or 
	diag("method channelMode() failed");
ok(not $i->isCopyrighted()) 									or 
	diag("method isCopyrighted() failed");
ok(not $i->isOriginal()) 										or 
	diag("method isOriginal() failed");