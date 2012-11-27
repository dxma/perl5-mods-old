use 5.005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'BerkeleyDB::SecIndices::Accessor',
    VERSION_FROM      => 'lib/BerkeleyDB/SecIndices/Accessor.pm', # finds $VERSION
    PREREQ_PM         => {
        BerkeleyDB => 0.27,
        YAML       => 0.58,
        Storable   => 2.15,
        File::Temp => 0.16, # testing code
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/BerkeleyDB/SecIndices/Accessor.pm', # retrieve abstract from module
       AUTHOR         => 'Dongxu Ma <dongxu@cpan.org>') : ()),
);
