#!/usr/bin/perl -w
################################################################
# $Id$
# $Author$
# $Date$
# $Rev$
################################################################

=head1 DESCRIPTION

A fake bin which contains custom methods for __get_qt_module_name

=cut

sub __get_custom_module_name {
    my ($name, $path ) = @_;
    
    require File::Spec;
    my $module = (File::Spec::->splitdir($path))[-2];
    return ($name, $module);
}

1;

=head1 AUTHOR

Copyright (C) 2007 - 2009 by Dongxu Ma <dongxu@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/artistic.html>

=cut

