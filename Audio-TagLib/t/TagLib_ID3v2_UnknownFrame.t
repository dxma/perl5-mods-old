# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ID3v2_UnknownFrame.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 5;
BEGIN { use_ok('Audio::TagLib::ID3v2::UnknownFrame') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY toString data frameID size setData
setText render headerSize textDelimiter);
can_ok("Audio::TagLib::ID3v2::UnknownFrame", @methods) 					or 
	diag("can_ok failed");

my $i = Audio::TagLib::ID3v2::UnknownFrame->new(Audio::TagLib::ByteVector->new(""));
isa_ok($i, "Audio::TagLib::ID3v2::UnknownFrame") 							or 
	diag("method new(data) failed");
is($i->toString()->toCString(), "") 								or 
	diag("method toString() failed");
SKIP: {
skip "data() skipped", 1 if 1;
is($i->data()->data(), undef) 										or 
	diag("method data() failed");
}