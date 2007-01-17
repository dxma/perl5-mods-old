use 5.008003;
use ExtUtils::MakeMaker;

BEGIN {
    # a simple work around to perform the neccessary pre-check
    # instead of overloading subs of MakeMaker or other wrapper
    print STDERR "ONLY support TagLib version 1.4.*\n";
    require Carp;
	# FIXME
	# openned for FreeBSD, OS X (darwin) and Cygwin
    Carp::croak("$^O is not supported currently") 
		unless $^O eq 'linux' or $^O eq 'freebsd' or $^O eq 'darwin' or 
		    $^O eq 'cygwin';
	Carp::croak("Please install taglib C++ package first") unless 
		system("taglib-config --version") == 0;
	our $libver = qx(taglib-config --version);
	chomp($libver);
	Carp::croak("Please install taglib ver 1.4.*") unless 
		$libver =~ m/^1\.4/io;
	our $libs = qx(taglib-config --libs);
	our $inc  = ' -I/usr/include -I./include -I. '. qx(taglib-config --cflags);
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Audio::TagLib',
    VERSION_FROM      => 'lib/Audio/TagLib.pm', # finds $VERSION
	LICENSE           => 'perl',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Audio/TagLib.pm', # retrieve abstract from module
       AUTHOR         => 'Dongxu, Ma <dongxu@cpan.org>') : ()),
    CC                => 'g++',
    LD                => 'g++',
    LDDLFLAGS         => $^O eq 'darwin' ? "-dynamiclib $libs" : "-shared ". $libs,
    XSOPT             => '-C++ -hiertype',
    LIBS              => $libs, 
    DEFINE            => $^O eq 'freebsd' ? '-D_BSD_ICONV -DNO_DOXYGEN' : '-DNO_DOXYGEN', # e.g., '-DHAVE_SOMETHING'
    INC               => $inc, # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);

package MY;

sub xs_c {
	my $cmd = shift->SUPER::xs_c(@_);
	$cmd .= << 'END';
	sed -i -e 's/newXSproto("TagLib/newXSproto("Audio::TagLib/g' $*.c
	sed -i -e 's/XS(boot_TagLib)/XS(boot_Audio__TagLib)/g' $*.c
END
	return $cmd;
}
