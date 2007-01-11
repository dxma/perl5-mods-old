use 5.008003;
use ExtUtils::MakeMaker;

BEGIN {
    # a simple work around to perform the neccessary pre-check
    # instead of overloading subs of MakeMaker or other wrapper
    print STDOUT "ONLY support TagLib version 1.4.* on Linux\n";
    require Carp;
	# FIXME
	# openned for FreeBSD
    Carp::croak("currently only support Linux\n") 
      unless $^O eq 'linux' or $^O eq 'freebsd';
    our $libpath = qx(taglib-config --prefix);
    chomp($libpath);
    our $incpath = $libpath . "/include/taglib";
    $libpath .= -d $libpath. "/lib64" ? "/lib64" : "/lib";
    my ($lib) = glob($libpath . "/libtag.so.1.4.*");
    if (defined $lib) {
        print STDOUT "got $lib, good, go on\n";
    } else {
        Carp::croak("version 1.4.* not found,". 
                    "please install firstly\n");
    }
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
    LDDLFLAGS         => "-shared -L${libpath}",
    XSOPT             => '-C++ -hiertype',
    LIBS              => ['-ltag'], # e.g., '-lm'
    DEFINE            => $^O eq 'freebsd' ? '-D_BSD_ICONV -DNO_DOXYGEN' : '-DNO_DOXYGEN', # e.g., '-DHAVE_SOMETHING'
    INC               => "-I${incpath} -I/usr/include -I./include ", # e.g., '-I. -I/usr/include/other'
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
