use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'FAQSlashdot',
    'VERSION_FROM' => 'faq/index.shtml', # finds $VERSION
);
