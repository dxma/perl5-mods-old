# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_FLAC_Properties.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
#use Test::More tests => 7;
use Test::More skip_all => "flac file too large to be attached with";
BEGIN { use_ok('Audio::TagLib::FLAC::Properties') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY length bitrate sampleRate channels
sampleWidth);
can_ok("Audio::TagLib::FLAC::Properties", @methods) 					or 
	diag("can_ok failed");

my $file = "sample/Discontent.flac";
my $flacfile = Audio::TagLib::FLAC::File->new($file);
my $i = $flacfile->audioProperties();
cmp_ok($i->length(), "==", 67) 									or 
	diag("method length() failed");
cmp_ok($i->bitrate(), "==", 475) 								or 
	diag("method bitrate() failed");
cmp_ok($i->sampleRate(), "==", 44100) 							or 
	diag("method sampleRate() failed");
cmp_ok($i->channels(), "==", 2) 								or 
	diag("method channels() failed");
cmp_ok($i->sampleWidth(), "==", 16) 							or 
	diag("method sampleWidth() failed");