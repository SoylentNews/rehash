use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::ScheduleShifts',
    'VERSION_FROM' => 'ScheduleShifts.pm', # finds $VERSION
    'PM'	=> { 'ScheduleShifts.pm' => '$(INST_LIBDIR)/ScheduleShifts.pm' },
);
