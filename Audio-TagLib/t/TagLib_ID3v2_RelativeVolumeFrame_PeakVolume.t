# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_ID3v2_RelativeVolumeFrame_PeakVolume.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 7;
BEGIN { use_ok('Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY bitsRepresentingPeak
setBitsRepresentingPeak peakVolume setPeakVolume);
can_ok("Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume", @methods) 	or
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume->new();
isa_ok($i, "Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume") 		or
	diag("method new() failed");
cmp_ok($i->bitsRepresentingPeak(), "==", 0) 						or
	diag("method bitsRepresentingPeak() failed");
$i->setBitsRepresentingPeak(16);
cmp_ok($i->bitsRepresentingPeak(), "==", 16) 						or
	diag("method setBitsRepresentingPeak(c) failed");
ok($i->peakVolume()->isEmpty()) 									or
	diag("method peakVolume() failed");
$i->setPeakVolume(Audio::TagLib::ByteVector->new("blah blah"));
is($i->peakVolume()->data(), "blah blah") 							or
	diag("method setPeakVolume(b) failed");
