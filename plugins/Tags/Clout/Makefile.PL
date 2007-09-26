# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Slash::Clout',
    'VERSION_FROM' => '../Clout.pm', # finds $VERSION
    'PM'        =>
        {
                'Describe.pm' => '$(INST_LIBDIR)/Clout/Describe.pm',
                'Moderate.pm' => '$(INST_LIBDIR)/Clout/Moderate.pm',
                'Vote.pm' =>     '$(INST_LIBDIR)/Clout/Vote.pm',
        },
);
