package Term::BashTab;

use 5.008007;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

use subs qw(new readline);

require Term::ReadLine;
our @ISA = qw(Term::ReadLine);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Term::BashTab ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
#our %EXPORT_TAGS = ( 'all' => [ qw(
#
#) ] );

#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

#our @EXPORT = qw(
#
#);

our $VERSION = '0.03';

# Default global command list
our @COMMAND = qw();
# Treat first param as ONLY command by default
our $FIRST_NOT_COMMAND = undef;
# Directory separator, Unix family by default
our $DIR_SEPARATOR = $^O eq 'MSWin32' ? q(\\)
  : q(/);

# Preloaded methods go here.

sub new {
    require Term::ReadLine;
    my $class = shift || __PACKAGE__;
    my $term = Term::ReadLine->new(@_);
    # re-blessed
    bless $term, $class;
}

sub __complete(@) {
    # @_ is (current last param, entire command line, length)
    my ($last, $cmd) = @_;
    #print "\n", $last, ":", $cmd, "\n";

    local *DIR;
    if($last eq $cmd and not $FIRST_NOT_COMMAND) {
        # one param only
        # complete list is @COMMAND if no input
        return @COMMAND if $cmd eq '';
        # complete list grepped from `keys $COMMAND'
        return sort grep { m/^\Q$last\E/ } @COMMAND;
    } else {
        my $path;
        if($FIRST_NOT_COMMAND) {
            $path = $cmd;
        } else {
            # command + path
            (undef, $path) = split / /, $cmd, 2;
        }

        my (@entry, @match);
        #print "\npath = '$path'\n";
        if($path) {
            # return if no need to complete
            return +() if
              substr($path, -1, 1) eq ' ' and
                -e substr($path, 0, length($path)-1);
            # glob all the matched entries if possible

            my $dirmatch_reg
              = $^O eq 'MSWin32' ? qr/^((?i:[a-z]\:\\)?(?:\\?[^\\]+)*)\\(.*)/o
                : qr{^((?:/?[^/]+)*)/(.*)}o;

            #if($path =~ m#^((?:/?[^/]*)*)/(.*)#o) {
            if ($path =~ $dirmatch_reg) {
                #print "\n1 = '$1'\n2 = '$2'";
                # $1 is basedir or null
                return +() unless -d $1.$DIR_SEPARATOR;

                opendir DIR, "$1$DIR_SEPARATOR" or do {
                    #warn "opendir: $!";
                    return +();
                };
                @entry = readdir DIR;
                closedir DIR or warn "closedir: $!";
                if($2) {
                    @match = sort grep { m/^\Q$2\E/ } @entry;
                    if(scalar(@match) == 1) {
                        # complete will add a ' ' automatically
                        # for a file ok
                        # for a dir this will block the
                        # following match
                        # a small trick here to remove the
                        # tail space for dir
                        my $file = $1.$DIR_SEPARATOR.$match[0];
                        #print $1, "\n";

                        my $complete;
                        # check space in $2 and then $1
                        # $1 will be replaced after next reg-match
                        my $dir = $1;
                        my $name = $2;
                        if ($name and $name =~ m/ /o) {
                            $complete = substr($match[0],
                                               rindex($name, " ")+1);
                        } elsif ($dir and $dir =~ m/ /o) {
                            $complete = (split / /, $dir)[-1].$DIR_SEPARATOR.$match[0];
                        } else {
                            $complete = $file;
                        }
                        if (-d $file) {
                            return +($complete.$DIR_SEPARATOR,
                                     $complete.$DIR_SEPARATOR." ");
                        } else {
                            return $complete;
                        }
                    } elsif (scalar(@match) == 0) {
                        # no match, no complete
                        return +();
                    } else {
                        # grep the match list and try to get the
                        # longest common string
                        my ($min_match) = (sort {
                            length($a) <=> length($b) } @match)[0];
                        my $min_length = length($min_match);
                        my $common;

                        COMMON: for (my $length =
                                       length($2);;$length++) {

                            if($length == $min_length) {
                                $common = $min_match;
                                last COMMON;
                            }

                            my $char = substr($match[0], $length, 1);
                            #print "\nchar = $char\n";
                            foreach (@match[1 .. $#match]) {
                                if(substr($_, $length, 1) ne $char) {
                                    $common = substr($match[0], 0,
                                                     $length);
                                    last COMMON;
                                }
                            }
                        }

                        if ($2 eq $common) {
                            # $2 is the longest common string
                            return +(@match, undef);
                        } else {
                            # check space in $2 and then $1
                            my $complete;
                            my $dir = $1;
                            my $name = $2;
                            #print $name, "\n";
                            if ($name and $name =~ m/ /o) {
                                $complete = substr($common,
                                                  rindex($name, " ")+1);
                            } elsif ($dir and $dir =~ m/ /o) {
                                $complete = (split / /, $dir)[-1].
                                  $DIR_SEPARATOR."$common";
                            } else {
                                $complete = $1.$DIR_SEPARATOR.$common;
                            }
                            return +("$complete",
                                     "$complete ");
                        }
                        # NOREACH
                    }
                } else {
                    return sort @entry;
                }
            } else {
                # search under cwd
                opendir DIR, "." or do {
                    #warn "opendir: $!";
                    return +();
                };
                @entry = readdir DIR;
                closedir DIR or warn "closedir: $!";
                @match = sort grep { m/^\Q$path\E/ } @entry;
                if(scalar(@match) == 1) {
                    my $file = $match[0];
                    my $complete;
                    # check space in $path
                    # $1 will be replaced after next reg-match
                    my $name = $path;
                    if ($name and $name =~ m/ /o) {
                        $complete = substr($match[0], rindex($path, " ")+1);
                    } else {
                        $complete = $file;
                    }
                    if (-d $file) {
                        return +($complete.$DIR_SEPARATOR,
                                 $complete.$DIR_SEPARATOR." ");
                    } else {
                        return $complete;
                    }
                } elsif (scalar(@match) == 0) {
                    return +();
                } else {
                    # grep the match list and try to get the
                    # longest common string
                    my ($min_match) = (sort {
                        length($a) <=> length($b) } @match)[0];
                    my $min_length = length($min_match);
                    my $common;

                    COMMON: for (my $length =
                                   length($path);;$length++) {

                        if($length == $min_length) {
                            $common = $min_match;
                            last COMMON;
                        }

                        my $char = substr($match[0], $length, 1);
                        foreach (@match[1 .. $#match]) {
                            if(substr($_, $length, 1) ne $char) {
                                $common = substr($match[0], 0,
                                                 $length);
                                last COMMON;
                            }
                        }
                    }

                    if ($path eq $common) {
                        # $path is the longest common string
                        return +(@match, undef);
                    } else {
                        # check space in $path
                        my $complete;
                        my $name = $path;
                        if ($name and $name =~ m/ /o) {
                            $complete = substr($common,
                                               rindex($name, " ")+1);
                        } else {
                            $complete = $common;
                        }
                        return +("$complete",
                                 "$complete ");
                    }
                    # NOREACH
                }
            }
        } else {
            # no param
            # ls all entries under cwd
            opendir DIR, "." or do {
                #warn "opendir: $!";
                return +();
            };
            @entry = readdir DIR;
            closedir DIR or warn "closedir: $!";
            return sort grep { /^[^.]/o } @entry;
        }
    }
    # NOREACH
}

sub readline {
    my $term   = shift;
    my $prompt = shift || '';
    # set callback stub
    my $attr   = $term->Attribs;
    if($term->ReadLine eq "Term::ReadLine::Gnu") {
        $attr->{attempted_completion_function} =
          __PACKAGE__."::__complete";
    } elsif($term->ReadLine eq "Term::ReadLine::Perl") {
        $attr->{completion_function} = __PACKAGE__."::__complete";
    } else {
        # Term::ReadLine::Stub
        # do nothing
    }
    return $term->SUPER::readline($prompt);
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Term::BashTab - A simple wrapper of ReadLine with bash-like E<lt>TABE<gt>

=head1 SYNOPSIS

  use Term::BashTab;

  my $term = Term::BashTab->new();
  print $term->readline("blah");

  then <TAB> blah <TAB> blah <TAB> ...

=head1 DESCRIPTION

A simple wrapper of L<Term::ReadLine|Term::ReadLine>, offerring bash-like E<lt>TABE<gt>
feature.

=over

=item WHEN TO USE

In order to get a valid program path or directory from user's
input. User can use E<lt>TABE<gt> to auto-complete.

=item HOW TO CONFIGURE

The module can parse two modes of input line:
I<command B<E<lt>ONE ENTIRE PATHE<gt>>>
and
I<B<E<lt>ONE ENTIRE PATHE<gt>>>

In the first mode, all commands/subs available to user is specified by
@Term::BashTab::COMMAND, local it to set your own list.

The second mode is enabled once $Term::BashTab::FIRST_NOT_COMMAND is
true. Local it when required somewhere. In this mode, the current
input line will be treated as ONE path.

Still not clear enough? Try playing with it in your free time ;-)

=item WHAT TO RETURN

The same as L<Term::ReadLine|Term::ReadLine>, readline invokes
Term::ReadLine::readline at last and returns the result.

=head2 EXPORT

The same as L<Term::ReadLine|Term::ReadLine>.



=head1 SEE ALSO

L<Term::ReadLine|Term::ReadLine>

=head1 AUTHOR

Dongxu Ma, E<lt>dongxu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
