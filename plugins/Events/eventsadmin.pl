#!/usr/bin/perl -w

use strict;
use Slash;
use Slash::Display;
use Slash::Events;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $events   = getObject('Slash::Events');

	redirect("/") 
		unless $user->{is_admin};
	header();
	if ($form->{op} eq 'delete') {
		$events->deleteDates($form->{id});
	} elsif ($form->{op} eq 'add') {
		$form->{end} ||= $form->{begin};
		$events->setDates($form->{sid} , $form->{begin}, $form->{end});
	}
	my $dates =  $events->getDatesBySid($form->{sid});
	my $title =  $events->getStory($form->{sid}, 'title');

	slashDisplay('index', {
		title 			=> $title,
		dates 			=> $dates,
		sid 			=> $form->{sid},
	});

	footer();
}

createEnvironment();
main();
1;
