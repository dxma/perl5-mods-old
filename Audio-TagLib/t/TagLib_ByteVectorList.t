# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_ByteVectorList.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More q(no_plan);
#use Test::More tests => 5;
BEGIN { use_ok('Audio::TagLib::ByteVectorList') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY toByteVector split);
can_ok("Audio::TagLib::ByteVectorList", @methods)		or 
	diag("can_ok failed");

my $i = Audio::TagLib::ByteVectorList->new();
my $j = Audio::TagLib::ByteVectorList->new($i);
isa_ok($i, "Audio::TagLib::ByteVectorList")			or 
	diag("method new() failed");
isa_ok($j, "Audio::TagLib::ByteVectorList") 			or 
	diag("method new(l) failed");

ok($i->toByteVector()->isEmpty()) 				or 
	diag("method toByteVector() failed");
my $v = Audio::TagLib::ByteVector->new("This is a test");
my $pattern = Audio::TagLib::ByteVector->new(" ");
my $k1 = Audio::TagLib::ByteVectorList->split($v, $pattern);
is($k1->toByteVector->data(), "This is a test") or 
	diag("method split(v, pattern) failed");