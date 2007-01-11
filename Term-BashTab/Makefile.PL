use 5.008007;
use ExtUtils::MakeMaker;

BEGIN {
    require Carp;
    Carp::croak("Currently ONLY support Linux, Sorry") unless $^O eq
      'linux' or $^O eq 'MSWin32';
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Term::BashTab',
    VERSION_FROM      => 'lib/Term/BashTab.pm', # finds $VERSION
    PREREQ_PM         => { Term::ReadLine => 1.01, }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Term/BashTab.pm', # retrieve abstract from module
       AUTHOR         => 'Dongxu Ma <dongxu@cpan.org>') : ()),
);
