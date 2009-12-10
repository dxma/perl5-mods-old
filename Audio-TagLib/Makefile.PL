use 5.008003;
use ExtUtils::MakeMaker;
use Config;

sub bail($) {
    my $reason = shift;
    warn $reason, $/;
    exit(0);
}

# a simple workaround to perform the necessary pre-checks
# instead of overloading MakeMaker subs or another wrapper

warn 'This module ONLY supports TagLib version 1.5.*', $/;

bail('Please install the taglib C++ library first')
  unless system('taglib-config --version') == 0;
  
chomp(my $libver = qx{taglib-config --version});

bail('Please install taglib ver 1.5.*')
  unless $libver =~ m/^1\.5/;

chomp(my $libs   = qx{taglib-config --libs});
$libs .= ' -L/System/Library/Perl/lib/'. $Config{version}. ' -lperl -liconv' if $^O eq 'darwin';
chomp(my $cflags = qx{taglib-config --cflags});

my $inc  = " -I/usr/include -I./include -I. $cflags";

WriteMakefile(
    NAME              => 'Audio::TagLib',
    VERSION_FROM      => 'lib/Audio/TagLib.pm', # finds $VERSION
    LICENSE           => 'perl',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    (
        $] >= 5.005                                           # Add these new keywords supported since 5.005
        ?                                                     
          (
            ABSTRACT_FROM => 'lib/Audio/TagLib.pm',           # retrieve abstract from module
            AUTHOR        => 'Dongxu, Ma <dongxu@cpan.org>'
          )
        : ()
    ),
    CC                => 'g++',
    LD                => 'g++',
    LDDLFLAGS         => $^O eq 'darwin' ? "-dynamiclib $libs" : "-shared ". $libs,
    XSOPT             => '-C++ -hiertype',
    LIBS              => $libs, 
    DEFINE            => ( $^O eq 'freebsd' || $^O eq 'darwin' ) ? '-D_BSD_ICONV -DNO_DOXYGEN' : '-DNO_DOXYGEN', # e.g., '-DHAVE_SOMETHING'
    INC               => $inc, # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);

package MY;

sub xs_c {
	my $cmd = shift->SUPER::xs_c(@_);
    $cmd .= sprintf(<<'END', $^X);
	%1$s -pi -e 's/newXSproto\("TagLib/newXSproto("Audio::TagLib/g' $*.c
	%1$s -pi -e 's/XS\(boot_TagLib\)/XS(boot_Audio__TagLib)/g' $*.c
END
	return $cmd;
}
