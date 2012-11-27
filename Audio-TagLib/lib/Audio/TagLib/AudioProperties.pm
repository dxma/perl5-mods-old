package Audio::TagLib::AudioProperties;

use 5.008003;
use strict;
use warnings;

our $VERSION = '1.41';

use Audio::TagLib;

our %_ReadStyle = (
    "Fast"     => 0,
    "Average"  => 1,
    "Accurate" => 2,
);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Audio::TagLib::AudioProperties - A simple, abstract interface to common audio
properties

=head1 DESCRIPTION

The values here are common to most audio formats.  For more specific,
codec dependant values, please see see the subclasses APIs.  This is
meant to compliment the L<Audio::TagLib::File|Audio::TagLib::File> and
L<Audio::TagLib::Tag|Audio::TagLib::Tag> APIs in providing a simple interface that
is sufficient for most applications.

=over

=item %_ReadStyle

Reading audio properties from a file can sometimes be very time
consuming and for the most accurate results can often involve reading
the entire file.  Because in many situations speed is critical or the
accuracy of the  values is not particularly important this allows the
level of desired accuracy to be set.

C<keys %Audio::TagLib::AudioProperties::_ReadStyle> lists all available
values used in Perl code.

see L<FLAC::Properties|Audio::TagLib::FLAC::Properties>
L<MPC::Properties|Audio::TagLib::MPC::Properties>
L<MPEG::Properties|Audio::TagLib::MPEG::Properties>
L<Vorbis::Properties|Audio::TagLib::Vorbis::Properties>

=item I<DESTROY()>

Destroys this AudioProperties instance.

=item I<length()> [pure virtual]

Returns the lenght of the file in seconds.

=item I<bitrate()> [pure virtual]

Returns the most appropriate bit rate for the file in kb/s.  For
constant bitrate formats this is simply the bitrate of the file.  For
variable bitrate formats this is either the average or nominal
bitrate.

=item I<sampleRate()> [pure virtual]

Returns the sample rate in Hz.

=item I<channels()> [pure virtual]

Returns the number of audio channels.

=back

=head2 EXPORT

None by default.



=head1 SEE ALSO

L<Audio::TagLib|Audio::TagLib>

=head1 AUTHOR

Dongxu Ma, E<lt>dongxu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
