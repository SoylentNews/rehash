#!/usr/bin/perl

# predata_dump.pl 1.19.00 Patrick Galbraith
# this file just makes sure that the data dump has your
# hostname in it instead of "www.yoursite.com"

chomp(my $hostname = shift || `hostname`);
open(DUMP,"<./slashdata_dump.sql") or die "can't locate slashdata_dump.sql! Where is it?";

while(<DUMP>) {
	s/www\.yoursite\.com/$hostname/g;
	$newdump .= $_;
}
close(DUMP);

open(DUMP,">slashdata_dump.sql") or die "can't locate slashdata_dump.sql! Where is it?";
print DUMP $newdump;
close(DUMP);

exit(0);


