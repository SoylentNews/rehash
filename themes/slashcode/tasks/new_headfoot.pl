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

	# shouldn't be necessary, since sectionHeaders() restores STDOUT before
	# exiting
	local *SO = *STDOUT;

	# With the new section code, this is most-likely no longer necessary.
	#sectionHeaders(@_, "");
	
	my $sections = $slashdb->getSections();
	for (keys %$sections) {
		my($section) = $sections->{$_}{section};
		mkpath "$constants->{basedir}/$section", 0, 0755;
		sectionHeaders(@_, $sections->{$_});
	}
	
	# Now since we've iterated thru all sections, just now, 
	# $user->{currentSection} is now set to the last section processed...
	# whatever that is [since header() sets $user->{currentSection}]. We
	# must undo this since this may affect template retrieval for other
	# tasks.
	#
	# Now the actual question: undef() or delete(). I'm assuming delete().
	# - Cliff 2002/05/22
	delete $user->{currentSection};

	*STDOUT = *SO;

	return ;
};

sub sectionHeaders {
	my($virtual_user, $constants, $slashdb, $user, $info, $sections) = @_;
	my $section = $sections->{section}
		if $sections;
	createCurrentHostname($sections->{hostname})
		if $sections;

	my $form = getCurrentForm();
	local(*STDOUT);

	setCurrentForm('ssi', 1);
	my $fh = gensym();

	open $fh, ">$constants->{basedir}/$section/slashhead.inc"
		or
	die "Can't open $constants->{basedir}/$section/slashhead.inc: $!";

	*STDOUT = $fh;
	header("", $section, { noheader => 1 });
	close $fh;

	setCurrentForm('ssi', 0);

	open $fh, ">$constants->{basedir}/$section/slashfoot.inc"
		or
	die "Can't open $constants->{basedir}/$section/slashfoot.inc: $!";

	*STDOUT = $fh;
	footer();
	close $fh;
}

1;

