# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_Vorbis_Properties.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 11;
BEGIN { use_ok('Audio::TagLib::Vorbis::Properties') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY length bitrate sampleRate channels
vorbisVersion bitrateMaximum bitrateNominal bitrateMinimum);
can_ok("Audio::TagLib::Vorbis::Properties", @methods) 						or 
	diag("can_ok failed");

my $file = "sample/Discontent.ogg";
my $oggfile = Audio::TagLib::Vorbis::File->new($file);
my $i = $oggfile->audioProperties();
isa_ok($i, "Audio::TagLib::Vorbis::Properties") 							or 
	diag("method Audio::TagLib::Vorbis::audioProperties() failed");
cmp_ok($i->length(), "==", 67) 										or 
	diag("method length() failed");
cmp_ok($i->bitrate(), "==", 128) 									or 
	diag("method bitrate() failed");
cmp_ok($i->sampleRate(), "==", 44100) 								or 
	diag("method sampleRate() failed");
cmp_ok($i->channels(), "==", 2) 									or 
	diag("method channels() failed");
cmp_ok($i->vorbisVersion(), "==", 0) 								or 
	diag("method vorbisVersion() failed");
cmp_ok($i->bitrateMaximum(), "==", -1000) 							or 
	diag("method bitrateMaximum() failed");
cmp_ok($i->bitrateNominal(), "==", 128000) 							or 
	diag("method bitrateNominal() failed");
cmp_ok($i->bitrateMinimum(), "==", -1000) 							or 
	diag("method bitrateMinimum() failed");
