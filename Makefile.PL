use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'HTTPD::WatchLog',
    'VERSION_FROM' => 'WatchLog.pm', # finds $VERSION
    'PREREQ_PM' => {
        File::Tail => 0.5,
	Class::Accessor	=> 0.10,
    },
);
