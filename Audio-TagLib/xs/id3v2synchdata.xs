#include "id3v2synchdata.h"

MODULE = TagLib			PACKAGE = TagLib::ID3v2::SynchData
PROTOTYPES: ENABLE

################################################################
# 
# PUBLIC FUNCTIONS in this NAMESPACE
# 
################################################################

static unsigned int 
TagLib::ID3v2::SynchData::toUInt(data)
	TagLib::ByteVector * data
CODE:
	RETVAL = TagLib::ID3v2::SynchData::toUInt(*data);
OUTPUT:
	RETVAL

static TagLib::ByteVector * 
TagLib::ID3v2::SynchData::fromUInt(value)
	unsigned int value
CODE:
	RETVAL = new TagLib::ByteVector(
		TagLib::ID3v2::SynchData::fromUInt(value));
OUTPUT:
	RETVAL

