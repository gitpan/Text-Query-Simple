use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

die "This module requires Perl 5.005 or higher" if $]<5.005;

WriteMakefile(
    'NAME'	=> 'Text::Query::Simple',
    'VERSION_FROM' => 'Simple.pm', # finds $VERSION
);
