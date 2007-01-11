package Audio::TagLib::Ogg::FLAC::File;

use 5.008003;
use strict;
use warnings;

our $VERSION = '1.41';

use Audio::TagLib;

our @ISA = qw(Audio::TagLib::Ogg::File);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Audio::TagLib::Ogg::FLAC::File -  An implementation of Audio::TagLib::File with
Ogg/FLAC specific methods 

=head1 SYNOPSIS

  use Audio::TagLib::Ogg::FLAC::File;
  
  my $i = Audio::TagLib::Ogg::FLAC::File->new("sample file.flac");
  print $i->tag()->album()->toCString(), "\n"; # got album

=head1 DESCRIPTION

This implements and provides an interface for Ogg/FLAC files to the
Audio::TagLib::Tag and Audio::TagLib::AudioProperties interfaces by way of
implementing the abstract Audio::TagLib::File API as well as providing some
additional information specific to Ogg FLAC files.

=over

=item I<new(PV $file, BOOL $readProperties = TRUE, PV $propertiesStyle
= "Average")>

Contructs an Ogg/FLAC file from $file. If $readProperties is true the
file's audio properties will also be read using $propertiesStyle. If
false, $propertiesStyle is ignored.

=item I<DESTROY()>

Destroys this instance of the File.

=item I<XiphComment tag()>

Returns the Tag for this file. This will always be a XiphComment.

=item I<L<Properties|Audio::TagLib::FLAC::Properties> audioProperties()>

Returns the FLAC::Properties for this file. If no audio properties
 were read then this will return undef.

=item I<BOOL save()>

Save the file. This will primarily save and update the
XiphComment. Returns true if the save is successful.

=item I<IV streamLength()>

Returns the length of the audio-stream, used by FLAC::Properties for
calculating the bitrate. 

=back

=head2 EXPORT

None by default.



=head1 SEE ALSO

L<Audio::TagLib|Audio::TagLib> L<Ogg::File|Audio::TagLib::Ogg::File>

=head1 AUTHOR

Dongxu Ma, E<lt>dongxu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
