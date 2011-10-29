# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl TagLib_Ogg_FieldListMap_Iterator.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More q(no_plan);
use Test::More tests => 8;
BEGIN { use_ok('Audio::TagLib::Ogg::FieldListMap::Iterator') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @methods = qw(new DESTROY data next last);
can_ok("Audio::TagLib::Ogg::FieldListMap::Iterator", @methods) 			or
	diag("can_ok failed");
my $item = Audio::TagLib::StringList->new();
$item->append(Audio::TagLib::String->new("item1"));
$item->append(Audio::TagLib::String->new("item2"));
my $key = Audio::TagLib::String->new("key");
my $key2 = Audio::TagLib::String->new("key2");
my $map = Audio::TagLib::Ogg::FieldListMap->new();
$map->insert($key, $item);
$map->insert($key2, $item);
my $i = $map->begin();
isa_ok($i, "Audio::TagLib::Ogg::FieldListMap::Iterator") 					or
	diag("method Audio::TagLib::Ogg::FieldListMap::begin failed");
isa_ok(Audio::TagLib::Ogg::FieldListMap::Iterator->new(),
	"Audio::TagLib::Ogg::FieldListMap::Iterator") 							or
	diag("method new() failed");
isa_ok(Audio::TagLib::Ogg::FieldListMap::Iterator->new($i),
	"Audio::TagLib::Ogg::FieldListMap::Iterator") 							or
	diag("method new(i) failed");

like($i->data()->toString()->toCString(),
	qr/^item1.*?item2$/) or diag("method data() failed");
like($i->next()->data()->toString()->toCString(),
	qr/^item1.*?item2$/) or diag("method next() failed");
like((--$i)->data()->toString()->toCString(),
	qr/^item1.*?item2$/) or diag("method last() failed");
