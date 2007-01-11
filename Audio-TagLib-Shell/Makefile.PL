use 5.008003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Audio::TagLib::Shell',
    VERSION_FROM      => 'lib/Audio/TagLib/Shell.pm', # finds $VERSION
    PREREQ_PM         => { Audio::TagLib => 1.4, Cwd => 2.06,
Term::BashTab => 0.02, }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Audio/TagLib/Shell.pm', # retrieve abstract from module
       AUTHOR         => 'Dongxu Ma <dongxu@cpan.org>') : ()),
);
