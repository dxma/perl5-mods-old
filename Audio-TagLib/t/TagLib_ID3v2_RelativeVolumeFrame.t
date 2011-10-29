# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_ID3v2_RelativeVolumeFrame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 7;
BEGIN { use_ok('Audio::TagLib::ID3v2::RelativeVolumeFrame') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY toString channels channelType
setChannelType volumeAdjustmentIndex setVolumeAdjustmentIndex
volumeAdjustment setVolumeAdjustment peakVolume setPeakVolume
frameID size setData setText render headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::RelativeVolumeFrame", @methods) 				or
	diag("can_ok failed");
TODO: {
local $TODO = "Audio::TagLib::ID3v2::RelativeVolumeFrame() not implemented";
#isa_ok(Audio::TagLib::ID3v2::RelativeVolumeFrame->new(),
#	"Audio::TagLib::ID3v2::RelativeVolumeFrame") 							or
#	diag("method new() failed");
}
my $i = Audio::TagLib::ID3v2::RelativeVolumeFrame->new(
	Audio::TagLib::ByteVector->new());
isa_ok($i, "Audio::TagLib::ID3v2::RelativeVolumeFrame") 					or
	diag("method new(data) failed");
#$i->setChannelType("BackCentre");
is($i->channelType(), "MasterVolume") 								or
	diag("method setChannelType(t) and channelType() failed");
$i->setVolumeAdjustmentIndex(20, "MasterVolume");
cmp_ok($i->volumeAdjustmentIndex(), "==", 20) 						or
	diag("method setVolumeAdjustmentIndex(index) and".
		" volumeAdjustmentIndex() failed");
$i->setVolumeAdjustment(20.20);
cmp_ok($i->volumeAdjustment(), "==", 0) 							or
	diag("method setVolumeAdjustment(adj) and".
		" valumeAdjustment() failed");
my $peak = Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume->new();
#$peak->setBitsRepresentingPeak(20);
#$peak->setPeakVolume(Audio::TagLib::ByteVector->new("blah blah"));
$i->setPeakVolume($peak);
isa_ok($i->peakVolume(),
	"Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume") 				or
	diag("method setPeakVolume(peak) and peakVolume() failed");
