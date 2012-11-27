#include "mpegheader.h"

MODULE = TagLib 		PACKAGE = TagLib::MPEG::Header
PROTOTYPES: ENABLE

################################################################
#
# PUBLIC MEMBER FUNCTIONS
#
################################################################

TagLib::MPEG::Header *
TagLib::MPEG::Header::new(...)
PROTOTYPE: $
PREINIT:
	TagLib::ByteVector *data;
	TagLib::MPEG::Header *h;
CODE:
	/*!
	 * Header(const ByteVector &data)
	 * Header(const Header &h)
	 */
	if(sv_isobject(ST(1))) {
		if(sv_derived_from(ST(1), "Audio::TagLib::ByteVector")) {
			data = INT2PTR(TagLib::ByteVector *, SvIV(SvRV(ST(1))));
			RETVAL = new TagLib::MPEG::Header(*data);
		} else if(sv_derived_from(ST(1), "Audio::TagLib::MPEG::Header")) {
			h = INT2PTR(TagLib::MPEG::Header *, SvIV(SvRV(ST(1))));
			RETVAL = new TagLib::MPEG::Header(*h);
		} else
			croak("ST(1) is not of type ByteVector/Header");
	} else
		croak("ST(1) is not a blessed object");
OUTPUT:
	RETVAL

void
TagLib::MPEG::Header::DESTROY()
CODE:
	if(!SvREADONLY(SvRV(ST(0))))
		delete THIS;

bool
TagLib::MPEG::Header::isValid()
CODE:
	RETVAL = THIS->isValid();
OUTPUT:
	RETVAL

TagLib::MPEG::Header::Version
TagLib::MPEG::Header::version()
CODE:
	RETVAL = THIS->version();
OUTPUT:
	RETVAL

int
TagLib::MPEG::Header::layer()
CODE:
	RETVAL = THIS->layer();
OUTPUT:
	RETVAL

bool
TagLib::MPEG::Header::protectionEnabled()
CODE:
	RETVAL = THIS->protectionEnabled();
OUTPUT:
	RETVAL

int
TagLib::MPEG::Header::bitrate()
CODE:
	RETVAL = THIS->bitrate();
OUTPUT:
	RETVAL

int
TagLib::MPEG::Header::sampleRate()
CODE:
	RETVAL = THIS->sampleRate();
OUTPUT:
	RETVAL

bool
TagLib::MPEG::Header::isPadded()
CODE:
	RETVAL = THIS->isPadded();
OUTPUT:
	RETVAL

TagLib::MPEG::Header::ChannelMode
TagLib::MPEG::Header::channelMode()
CODE:
	RETVAL = THIS->channelMode();
OUTPUT:
	RETVAL

bool
TagLib::MPEG::Header::isCopyrighted()
CODE:
	RETVAL = THIS->isCopyrighted();
OUTPUT:
	RETVAL

bool
TagLib::MPEG::Header::isOriginal()
CODE:
	RETVAL = THIS->isOriginal();
OUTPUT:
	RETVAL

int
TagLib::MPEG::Header::frameLength()
CODE:
	RETVAL = THIS->frameLength();
OUTPUT:
	RETVAL

void
TagLib::MPEG::Header::copy(h)
	TagLib::MPEG::Header * h
PPCODE:
	(void)THIS->operator=(*h);
	XSRETURN(1);

