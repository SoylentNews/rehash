#!/usr/bin/perl -w

use strict;
use Slash;
use File::Path;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '3,33 * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info) = @_;

	sectionHeaders(@_, "");
	my $sections = $slashdb->getSections();
	for (keys %$sections) {
		my($section) = $sections->{$_}{section};
		mkpath "$constants->{basedir}/$section", 0, 0755;
		sectionHeaders(@_, $sections->{$_});
	}

	return ;
};

sub sectionHeaders {
	my($virtual_user, $constants, $slashdb, $user, $info, $sections) = @_;
	my $section = $sections->{section}
		if $sections;

	createCurrentHostname($sections->{hostname})
		if $sections;

	my $form = getCurrentForm();

	setCurrentForm('ssi', 1);
	my $fh = gensym();

	my $head_pages = $slashdb->getHeadFootPages($section, 'header');

	foreach (@$head_pages) {
		my $file;

		if ($_->[0] eq 'misc') {
			$file = "$constants->{basedir}/$section/slashhead.inc";
		} else {
			$file = "$constants->{basedir}/$section/slashhead-$_->[0].inc";
		}

		open $fh, ">$file" or die "Can't open $file : $!";
		my $header = header("", $section, { noheader => 1, Return => 1, Page => $_->[0] });
		print $fh $header;
		close $fh;
	}

	setCurrentForm('ssi', 0);
	open $fh, ">$constants->{basedir}/$section/slashfoot.inc"
		or die "Can't open $constants->{basedir}/$section/slashfoot.inc: $!";
	my $footer = footer({ Return => 1 });
	print $fh $footer;
	close $fh;
}

1;

