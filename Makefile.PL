use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::Chimps::Anna',
    AUTHOR              => 'Zev Benjamin <zev@cpan.org>',
    VERSION_FROM        => 'lib/Test/Chimps/Anna.pm',
    ABSTRACT_FROM       => 'lib/Test/Chimps/Anna.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-Chimps-Anna-*' },
);
