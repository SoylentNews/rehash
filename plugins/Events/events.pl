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

	$form->{date} ||= timeCalc($slashdb->getTime(), '%Y-%m-%d');

	my $next = $events->getDayNext($form->{date});
	my $previous = $events->getDayPrevious($form->{date});

	my $stories =  $events->getEventsByDay($form->{date});
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
				next			=> $next,
				previous		=> $previous,
			});
		} else {
			my $message = "Sorry, boring day, nothing found for $time";
			header($message);
			print $message;
		}
		footer();
	}
}

createEnvironment();
main();
1;
