# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl TagLib_APE_Item.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 14;
BEGIN { use_ok('Audio::TagLib::APE::Item') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY copy key value size toString
toStringList render parse setReadOnly isReadOnly setType type
isEmpty);
can_ok("Audio::TagLib::APE::Item", @methods) 					or 
	diag("can_ok failed");

ok(Audio::TagLib::APE::Item->new()->isEmpty()) 				or 
	diag("method new() failed");
my $key    = Audio::TagLib::String->new("test");
my $value  = Audio::TagLib::String->new("This is a test");
my $values = Audio::TagLib::StringList->new($value);
my $i      = Audio::TagLib::APE::Item->new($key, $value);
my $j      = Audio::TagLib::APE::Item->new($key, $values);
my $k      = Audio::TagLib::APE::Item->new($i);
my $l      = Audio::TagLib::APE::Item->new();

is($i->key()->toCString(), $key->toCString()) 			or 
	diag("method key() failed");
cmp_ok($i->value()->data(), "==",  undef) 				or 
	diag("method value() failed");
cmp_ok($i->size(), "==", 13) 							or 
	diag("method size() failed");
is($i->toString()->toCString(), $value->toCString()) 	or 
	diag("method toString() failed");
is($i->toStringList()->toString()->toCString(), $value->toCString()) 
	or diag("method toStringList() failed");
cmp_ok($i->render()->size(), "==", 27) 					or 
	diag("method render() failed");
$l->parse($i->render());
is($l->key()->toCString(), $key->toCString()) 			or 
	diag("method parse() failed");
$i->setReadOnly(1);
ok($i->isReadOnly()) 									or 
	diag("method setReadOnly() failed");
$i->setReadOnly(0);
ok(not $i->isReadOnly()) 								or 
	diag("method isReadOnly() failed");
$i->setType("Binary");
is($i->type(), "Binary") 								or 
	diag("method type() failed");
$i->setType("Text");
ok(not $i->isEmpty()) 									or 
	diag("method isEmpty() failed");
