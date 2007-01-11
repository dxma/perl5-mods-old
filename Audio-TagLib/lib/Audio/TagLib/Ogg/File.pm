package Audio::TagLib::Ogg::File;

use 5.008003;
use strict;
use warnings;

our $VERSION = '1.41';

use Audio::TagLib;

our @ISA = qw(Audio::TagLib::File);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Audio::TagLib::Ogg::File - An implementation of Audio::TagLib::File with some
helpers for Ogg based formats 

=head1 DESCRIPTION

This is an implementation of Ogg file page and packet rendering and is
of use to Ogg based formats. While the API is small this handles the
non-trivial details of breaking up an Ogg stream into packets and
makes these available (via subclassing) to the codec meta data
implementations. 

=over

=item I<DESTROY()>

Destroys the instance of File.

=item I<L<ByteVector|Audio::TagLib::ByteVector> packet(UV $i)>

Returns the packet contents for the i-th packet (starting from zero)
in the Ogg bitstream.

B<WARNING> The requires reading at least the packet header for every
page up to the requested page.

=item I<void setPacket(UV $i, L<ByteVector|Audio::TagLib::ByteVector> $p)>

Sets the packet with index $i to the value $p.

=item I<L<PageHeader|Audio::TagLib::Ogg::PageHeader> firstPageHeader()>

Returns the PageHeader for the first page in the stream or undef if
the page could not be found.

=item I<L<PageHeader|Audio::TagLib::Ogg::PageHeader> lastPageHeader()>

Returns the PageHeader for the last page in the stream or undef if the
page could not be found.

=item I<BOOL save()>

Saves the file.

=back

=head2 EXPORT

None by default.



=head1 SEE ALSO

L<Audio::TagLib|Audio::TagLib> L<File|Audio::TagLib::File>

=head1 AUTHOR

Dongxu Ma, E<lt>dongxu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
