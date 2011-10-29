#include "vorbisfile.h"

MODULE = TagLib			PACKAGE = TagLib::Ogg::Vorbis::File
PROTOTYPES: ENABLE

################################################################
#
# PUBLIC MEMBER FUNCTIONS
#
################################################################

TagLib::Ogg::Vorbis::File *
TagLib::Ogg::Vorbis::File::new(file, readProperties=true, propertiesStyle=TagLib::AudioProperties::Average)
	char * file
	bool readProperties
	TagLib::AudioProperties::ReadStyle propertiesStyle
CODE:
	RETVAL = new TagLib::Ogg::Vorbis::File(file, readProperties,
		propertiesStyle);
OUTPUT:
	RETVAL

void
TagLib::Ogg::Vorbis::File::DESTROY()
CODE:
	if(!SvREADONLY(SvRV(ST(0))))
		delete THIS;

void
TagLib::Ogg::Vorbis::File::tag()
INIT:
	TagLib::Ogg::XiphComment * tag = THIS->tag();
PPCODE:
	if(tag != NULL) {
		ST(0) = sv_newmortal();
		sv_setref_pv(ST(0), "Audio::TagLib::Ogg::XiphComment", (void *)tag);
		SvREADONLY_on(SvRV(ST(0)));
		XSRETURN(1);
	} else
		XSRETURN_UNDEF;

void
TagLib::Ogg::Vorbis::File::audioProperties()
INIT:
	TagLib::Ogg::Vorbis::Properties * p = THIS->audioProperties();
PPCODE:
	if(p != NULL) {
		ST(0) = sv_newmortal();
		sv_setref_pv(ST(0), "Audio::TagLib::0gg::Vorbis::Properties", (void *)p);
		SvREADONLY_on(SvRV(ST(0)));
		XSRETURN(1);
	} else
		XSRETURN_UNDEF;

bool
TagLib::Ogg::Vorbis::File::save()
CODE:
	RETVAL = THIS->save();
OUTPUT:
	RETVAL

