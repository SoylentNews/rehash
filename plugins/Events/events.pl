#!/usr/bin/perl -w

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $events   = getObject('Slash::Events');

	$form->{date} ||= timeCalc(0, '%Y-%m-%d');

	my $date = $form->{date};
	if ($form->{op} eq 'previousDate') {
		$date = $events->getDayPrevious($date);
	} elsif ($form->{op} eq 'nextDate') {
		$date = $events->getDayNext($date);
	}


	my $stories =  $events->getEventsByDay($date);
	my $time = timeCalc($form->{date}, '%A %B %d', 0);
	if ($form->{content_type} eq 'rss') {
		my @items;
		for my $entry (@$stories) {
			push @items, {
				title	=> $entry->[1],
				'link'	=> ($constants->{absolutedir} . "/article.pl?sid=$entry->[0])"),
			};
		}

		xmlDisplay(rss => {
			channel => {
				title		=> "$constants->{sitename} events for nick's $time",
				'link'		=> "$constants->{absolutedir}/",
			},
			image	=> 1,
			items	=> \@items
		});
	} else {
		if (@$stories) {
			header($time, $form->{section});
			slashDisplay('events', {
				title 			=> $time,
				events 			=> $stories,
				'date'  		=> $date,
			});
		} else {
			my $message = getData('notfound');
			header($message);
			print $message;
		}
		footer();
	}
}

createEnvironment();
main();
1;
