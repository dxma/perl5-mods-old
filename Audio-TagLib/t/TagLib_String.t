# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_String.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 41;
use Encode qw(encode decode);
BEGIN { use_ok('Audio::TagLib::String') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY to8Bit toCString begin end find substr
append upper size isEmpty isNull data toInt stripWhiteSpace getChar
_equal _append copy _lessThan number null);
can_ok("Audio::TagLib::String", @methods) or diag("can_ok failed");

my $i = Audio::TagLib::String->new();
my $s_latin1 = Audio::TagLib::String->new(Audio::TagLib::String->new("blah blah"));
is($s_latin1->to8Bit(), "blah blah")						or
	diag("method new(ascii) failed");
is(Audio::TagLib::String->new(Audio::TagLib::ByteVector->new(
	"blah blah"))->to8Bit(), "blah blah") or 
	diag("method new(ByteVector) failed");

my $gb2312 			= chr(0316).chr(0322).chr(0265).chr(0304);
my $utf8_hardcode 	= "\x{6211}\x{7684}";
my $utf8 			= decode("GB2312", $gb2312);
my $utf16be 		= encode("UTF16BE", $utf8);
my $utf16le 		= encode("UTF16LE", $utf8);
my $utf16 			= encode("UTF16", $utf8);
my $s_utf8 = Audio::TagLib::String->new($utf8);
is($s_utf8->to8Bit("true"), $utf8_hardcode)					or 
	diag("method new(utf8) failed");
is(Audio::TagLib::String->new($utf8_hardcode)->to8Bit("true"),$utf8_hardcode)
	or diag("method new(utf8) failed");
is(Audio::TagLib::String->new($utf8, "UTF8")->to8Bit("true"), $utf8_hardcode)
	or diag("method new(utf8, \"UTF8\") failed");
my $s_utf16be = Audio::TagLib::String->new($utf16be, "UTF16BE");
is($s_utf16be->to8Bit("true"), $utf8_hardcode) 				or 
	diag("method new(utf16be, \"UTF16BE\") failed");
my $s_utf16le = Audio::TagLib::String->new($utf16le, "UTF16LE");
is($s_utf16le->to8Bit("true"), $utf8_hardcode) 				or 
	diag("method new(utf16le, \"UTF16LE\") failed");
my $s_utf16 = Audio::TagLib::String->new($utf16, "UTF16");
is($s_utf16->to8Bit("true"), $utf8_hardcode) 				or 
	diag("method new(utf16, \"UTF16\") failed");
is($s_utf16->toCString("true"), $utf8_hardcode) 			or 
	diag("method toCString(O failed");

cmp_ok($s_latin1->find(Audio::TagLib::String->new("ah")), "==", 2) 	or 
	diag("method find(string) failed");
cmp_ok($s_latin1->find(Audio::TagLib::String->new("ah"), 4), "==", 7) 	or 
	diag("method find(string, offset) failed");
is($s_latin1->substr(0, 4)->to8Bit(), "blah")					or
	diag("method substr(position, n) failed");
is($s_utf16be->substr(0, 2)->to8Bit("true"), $utf8_hardcode) 	or
	diag("method substr(position, n) failed");
is($s_latin1->append(Audio::TagLib::String->new(" blah"))->to8Bit(), 
	"blah blah blah") or diag("method append(string) failed");
is($s_utf8->append($s_utf16be)->to8Bit("true"), $utf8_hardcode x 2) 
	or diag("method append(string) failed");
$s_latin1 = $s_latin1->substr(0, 9);
$s_utf8 = $s_utf8->substr(0, 2);
is($s_latin1->upper()->to8Bit(), "BLAH BLAH") 					or
	diag("method upper() failed");
cmp_ok($s_latin1->size(), "==", length($s_latin1->to8Bit())) 	or
	diag("method size() failed");
cmp_ok($s_utf8->size(), "==", length($s_utf8->to8Bit("true"))) 	or
	diag("method size() failed");
ok(Audio::TagLib::String->new()->isEmpty()) 							or
	diag("method isEmtpy() failed");
ok(not $s_latin1->isEmpty()) 									or
	diag("method isEmtpy() failed");
ok(Audio::TagLib::String->null()->isNull()) 							or 
	diag("method null() failed");
ok(not $s_latin1->isNull()) 									or 
	diag("method isNull() failed");
is($s_latin1->data("Latin1")->data(), "blah blah") 				or
	diag("method data(latin1) failed");
is($s_utf8->data("UTF8")->data(), $utf8_hardcode) 				or
	diag("method data(utf8) failed");
TODO: {
local $TODO = "bug while t=UTF16BE, got UTF16LE";
is($s_utf8->data("UTF16BE")->data(), $utf16be) 					or
	diag("method data(utf16be) failed");
}
is($s_utf8->data("UTF16LE")->data(), $utf16le) 					or
	diag("method data(utf16le) failed");
TODO: {
local $TODO = "bug while t=UTF16, got UTF16LE, should be UTF16BE";
is($s_utf8->data("UTF16")->data(), $utf16) 						or 
	diag("method data(utf16) failed");
}
cmp_ok(Audio::TagLib::String->new("a")->toInt(), "==", oct("a")) 		or
	diag("method toInt() failed");
is(Audio::TagLib::String->new("   blah   ")->stripWhiteSpace()->to8Bit(), 
	"blah") or diag("method stripWhiteSpace() failed");
is($s_latin1->getChar(1), "l") 									or 
	diag("method getChar(i) failed");
is($s_utf8->getChar(1), "\x{7684}") 							or 
	diag("method getChar(i) failed");
ok($s_latin1 == Audio::TagLib::String->new("blah blah")) 				or 
	diag("method _equal(s, '') failed");
ok($s_utf8 == Audio::TagLib::String->new($utf8_hardcode)) 				or 
	diag("method _equal(s, '') failed");
$s_latin1 += " blah";
is($s_latin1->toCString(), "blah blah blah") 					or 
	diag("method _append(string) failed");
$s_latin1 += Audio::TagLib::String->new(" blah");
is($s_latin1->toCString(), "blah blah blah blah") 				or 
	diag("method _append(String) failed");
$s_utf8 += "test";
is($s_utf8->toCString("true"), $utf8_hardcode . "test") 		or 
	diag("method _append(string) failed");
ok(Audio::TagLib::String->new("a") < Audio::TagLib::String->new("b")) 		or 
	diag("method _lessThan(string) failed");
ok(Audio::TagLib::String->new("b") > Audio::TagLib::String->new("a")) 		or 
	diag("method _lessThan(string) failed");
is(Audio::TagLib::String->number(10)->toCString(), "10") 				or 
	diag("method number(string) failed");
SKIP: {
 skip "copy(s) skipped", 0 if 1;
}