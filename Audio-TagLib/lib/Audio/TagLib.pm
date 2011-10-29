package Audio::TagLib;

use 5.008003;
use strict;
use warnings;

our $VERSION = '1.43';

require XSLoader;
XSLoader::load('Audio::TagLib', $VERSION);

# fill overload stash in each sub-package
use Audio::TagLib::APE::Footer;
use Audio::TagLib::APE::Item;
use Audio::TagLib::AudioProperties;
use Audio::TagLib::FLAC::Properties;
use Audio::TagLib::MPC::Properties;
use Audio::TagLib::MPEG::Properties;
use Audio::TagLib::Ogg::Vorbis::Properties;
use Audio::TagLib::Vorbis::Properties;
use Audio::TagLib::ByteVector;
use Audio::TagLib::ByteVector::Iterator;
use Audio::TagLib::File;
use Audio::TagLib::FLAC::File;
use Audio::TagLib::MPC::File;
use Audio::TagLib::MPEG::File;
use Audio::TagLib::Ogg::File;
use Audio::TagLib::Ogg::FLAC::File;
use Audio::TagLib::Ogg::Vorbis::File;
use Audio::TagLib::Vorbis::File;
use Audio::TagLib::FileRef;
use Audio::TagLib::FileRef::FileTypeResolver;
use Audio::TagLib::ID3v1::StringHandler;
use Audio::TagLib::ID3v2::ExtendedHeader;
use Audio::TagLib::ID3v2::Footer;
use Audio::TagLib::ID3v2::Frame;
use Audio::TagLib::ID3v2::AttachedPictureFrame;
use Audio::TagLib::ID3v2::CommentsFrame;
use Audio::TagLib::ID3v2::RelativeVolumeFrame;
use Audio::TagLib::ID3v2::TextIdentificationFrame;
use Audio::TagLib::ID3v2::UserTextIdentificationFrame;
use Audio::TagLib::ID3v2::UniqueFileIdentifierFrame;
use Audio::TagLib::ID3v2::UnknownFrame;
use Audio::TagLib::ID3v2::FrameFactory;
use Audio::TagLib::ID3v2::Header;
use Audio::TagLib::ID3v2::RelativeVolumeFrame::PeakVolume;
use Audio::TagLib::ByteVectorList;
use Audio::TagLib::StringList;
use Audio::TagLib::MPEG::Header;
use Audio::TagLib::MPEG::XingHeader;
use Audio::TagLib::Ogg::Page;
use Audio::TagLib::Ogg::PageHeader;
use Audio::TagLib::String;
use Audio::TagLib::String::Iterator;
use Audio::TagLib::Tag;
use Audio::TagLib::APE::Tag;
use Audio::TagLib::APE::ItemListMap;
use Audio::TagLib::APE::ItemListMap::Iterator;
use Audio::TagLib::ID3v1::Tag;
use Audio::TagLib::ID3v2::Tag;
use Audio::TagLib::ID3v2::FrameList;
use Audio::TagLib::ID3v2::FrameList::Iterator;
use Audio::TagLib::ID3v2::FrameListMap;
use Audio::TagLib::ID3v2::FrameListMap::Iterator;
use Audio::TagLib::Ogg::XiphComment;
use Audio::TagLib::Ogg::FieldListMap;
use Audio::TagLib::Ogg::FieldListMap::Iterator;
use Audio::TagLib::ID3v1;
use Audio::TagLib::ID3v1::GenreMap;
use Audio::TagLib::ID3v1::GenreMap::Iterator;
use Audio::TagLib::ID3v2::SynchData;

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Audio::TagLib -  a library for reading and editing audio meta data, commonly
known as I<tags>.

=head1 SYNOPSIS

  use Audio::TagLib;
  use warnings;
  use strict;

  my $f      = Audio::TagLib::FileRef->new("Latex Solar Beef.mp3");
  my $artist = $f->tag()->artist();
  print $artist->toCString(), "\n"; # got "Frank Zappa"

  $f->tag()->setAlbum(Audio::TagLib::String->new("Fillmore East"));
  $f->save();

  my $g      = Audio::TagLib::FileRef->new("Free City Rhymes.ogg");
  my $album  = $g->tag()->album();
  print $album->toCString(), "\n";  # got "NYC Ghosts & Flowers"

  $g->tag()->setTrack(1);
  $g->save();

B<Note> that these high level functions work for Ogg, FLAC, MPC and
MP3 (or any other formats supported in the future).  For this high
level API, which is suitable for most applications, the differences
between tag and file formats can all be ignored.

=head1 DESCRIPTION

Some goals of TagLib:
 - A clean, high level, C++ API to handling audio meta data.
 - Support for at least ID3v1, ID3v2 and Ogg Vorbis comments.
 - A generic, simple API for the most common tagging related functions.
 - Binary compatibility between minor releases using the standard
KDE/Qt techniques for C++ binary compatibility.
 - Make the tagging framework extensible by library users; i.e. it
will be possible for libarary users to implement  additional ID3v2
frames, without modifying the TagLib source (through the use of
I<Abstract Factories> and such.

Because TagLib desires to be toolkit agnostic, in hope of being widely
adopted and the most flexible in licensing
TagLib provides many of its own toolkit classes; in fact the only
external dependancy that TagLib has, it a semi-sane STL implementation.

=over

=item B<Why I<TagLib>> ?

 TagLib was written to fill a gap in the Open Source/Free Software
 community. Currently there is a lack in the OSS/FS for a homogenous
 API to the most common music types.

As TagLib will be initially injected into the KDE community, while it
has not been linked to any of the KDE or Qt libraries
Scott has tried to follow the coding style of those libraries.  Again,
this is in sharp contrast to id3lib, which basically provides a hybrid
C/C++ API and uses a dubious object model.

Scott gets asked rather frequently why he is replacing I<id3lib>
(mostly by people that have never worked with I<id3lib>), if you are
concerned about this please email him; He can provide his lengthy
standard rant. You can also email me if you like. I will talk to him
:-)

=back

=head2 EXPORT

None by default.

=head1 ENUM TYPE MAPPING

All over TagLib in Perl, ALL the enum value is mapped to a specific
string. For instace, Audio::TagLib::String::UTF8 => "UTF8". Usually there
will be a hash you can query all the available values.

=head1 NAMESPACE ISSUE

Audio::TagLib::Ogg::Vorbis and Audio::TagLib::Vorbis are normally the same.

In C/C++, namespace Ogg is controlled by the macro DOXYGEN. When
defined, there will be Audio::TagLib::Ogg::Vorbis existing. Otherwize, they
just import all the symbols from Audio::TagLib::Vorbis to
Audio::TagLib::Ogg::Vorbis.

In Perl, nearly the same. It will make one stash be the alias of
another. Refer to Audio::TagLib::Ogg::Vorbis::File.pm, for instance.

=head1 FUNCTION PROTOTYPE

currently all XS stubs will be imported into Perl namespace with
specific prototype, just the same as internal functions.
Prototype triggers a type map sometimes silently since it introduces
context to each param.

A very simple way to get rid of prototype surrounding:

C<< eval { use __PACKAGE__; 1; } or croak("package import failed:
$@"); >>

Normally, just C<< require __PACKAGE__; >> since no symbol exported
from L<TagLib|Audio::TagLib> ;P

=head1 THREAD SAFETY

Currently NOT implemented.

=head1 OTHER STUFF YOU SHOULD KNOW

some methods will often return certain internal structure of an
instance, for example, I<tag()> & I<audioProperties()> in all
subclasses of L<AudioProperties|Audio::TagLib::AudioProperties>. In such
case, a READONLY flag is set on for the returned structure to bypass
I<DESTROY()>.

=head1 SEE ALSO

F<http://developer.kde.org/~wheeler/taglib.html>

=head1 KNOWN BUGS

Refer to I<Bugs> in the top level of the package

=head1 CREDITS

Scott Wheeler E<lt>wheeler@kde.orgE<gt>

=head1 AUTHOR

Dongxu Ma E<lt>dongxu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 - 2006 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut
