#!/usr/bin/perl -w
use File::Copy;
use File::Spec::Functions;
for (qw(INSTALL README)) {
    print "Converting $_.pod to text\n";
    system "pod2text $_.pod > $_";
    print "Converting $_.pod to HTML\n";
    system "pod2html $_.pod > $_.html";
    print "Copying $_ to parent directory\n";
    copy $_, catfile(updir, $_) or warn "Couldn't copy\n";
}
