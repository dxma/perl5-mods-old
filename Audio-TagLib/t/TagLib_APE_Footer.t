# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_APE_Footer.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 20;
#use Test::More q(no_plan);
BEGIN { use_ok('Audio::TagLib::APE::Footer') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY version);
can_ok("Audio::TagLib::APE::Footer", @methods) 			or
	diag("can_ok failed");

my $i = Audio::TagLib::APE::Footer->new();
cmp_ok($i->version(), "==", 0)					or
	diag("new() failed");
cmp_ok(Audio::TagLib::APE::Footer->new(Audio::TagLib::ByteVector->new("blah"))->version(),
	"==", 0) or diag("new(ByteVector v) failed");

ok(not $i->headerPresent())		or
	diag("method headerPresent() failed");
ok($i->footerPresent())			or
	diag("method footerPresent() failed");
ok(not $i->isHeader())			or
	diag("method isHeader() failed");
$i->setHeaderPresent(1);
ok($i->headerPresent())			or
	diag("method setHeaderPresent() failed");
$i->setHeaderPresent(0);
cmp_ok($i->itemCount(), "==", 0)	or
	diag("method itemCount() failed");
$i->setItemCount(3);
cmp_ok($i->itemCount(), "==", 3)	or
	diag("method setItemCount failed");
$i->setItemCount(0);
cmp_ok($i->tagSize(), "==", 0)		or
	diag("method tagSize() failed");
cmp_ok($i->completeTagSize(), "==", 0) 	or
	diag("method completeTagSize() failed");
$i->setTagSize(3);
cmp_ok($i->tagSize(), "==", 3)		or
	diag("method setTagSize() failed");
cmp_ok($i->completeTagSize(), "==", 3) 	or
	diag("method setTagSize() failed");
$i->setTagSize(0);
# can NOT test setData()
$i->setData(Audio::TagLib::ByteVector->new("blah"x8));
like($i->renderFooter()->data(), qr(^APETAGEX))	or
	diag("method renderFooter() failed");
cmp_ok($i->renderHeader()->data(), "==", undef)	or
	diag("method renderHeader() failed");
cmp_ok($i->size(), "==", 32)			or
	diag("method size() failed");
cmp_ok(Audio::TagLib::APE::Footer->size(), "==", 32)	or
	diag("method size() failed");
like($i->fileIdentifier()->data(), qr(^APETAGEX))
	or diag("method fileIdentifier() failed");
like(Audio::TagLib::APE::Footer->fileIdentifier()->data(), qr(^APETAGEX))
	or diag("method fileIdentifier() failed");
