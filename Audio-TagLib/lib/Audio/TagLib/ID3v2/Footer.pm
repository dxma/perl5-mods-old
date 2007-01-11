package Audio::TagLib::ID3v2::Footer;

use 5.008003;
use strict;
use warnings;

our $VERSION = '1.41';

use Audio::TagLib;

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Audio::TagLib::ID3v2::Footer - ID3v2 footer implementation

=head1 SYNOPSIS

  use Audio::TagLib::ID3v2::Footer;
  
  my $i = Audio::TagLib::ID3v2::Footer->new();
  my $v = $i->render($header);

=head1 DESCRIPTION

Per the ID3v2 specification, the tag's footer is just a copy of the
information in the header. As such there is no API for reading the
data from the header, it can just as easily be done from the header.

In fact, at this point, Audio::TagLib does not even parse the footer since it
is not useful internally. However, if the flag to include a footer has
been set in the ID3v2::Tag, Audio::TagLib will render a footer.

=over

=item I<new()>

Constructs an empty ID3v2 footer.

=item I<DESTROY()>

Destroys the footer.

=item I<UV size()> [static]

Returns the size of the footer. Presently this is always 10 bytes. 

=item I<L<ByteVector|Audio::TagLib::ByteVector>
render(L<Header|Audio::TagLib::ID3v2::Header> $header)> 

Renders the footer based on the data in $header.

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
