use 5.010;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'PDF::Table',
    VERSION_FROM      => 'lib/PDF/Table.pm', # finds $VERSION
    MIN_PERL_VERSION  => 5.010000, # Perl 5.10 minimum
    LICENSE           => 'perl_5',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/PDF/Table.pm', # retrieve abstract from module
    AUTHOR            => 'Phil Perry <omega@cpan.org>',
    META_MERGE        => {
        resources => {
            bugtracker => 'https://github.com/PhilterPaper/PDF-Table/issues',
            repository => 'https://github.com/PhilterPaper/PDF-Table',
        },
    },
);
