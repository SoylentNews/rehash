#!/usr/bin/perl -w

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use HTML::CalendarMonth;
use HTML::AsSubs;



##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $events   = getObject('Slash::Events');

	header() 
		unless $form->{plain};
	# Using HTML::AsSubs
	my $cal = HTML::CalendarMonth->new( month => 01, year => 2002 );
	$cal->item($cal->year, $cal->month)->attr(bgcolor => 'wheat');
	$cal->item($cal->year, $cal->month)->wrap_content(font({size => '+2'}));
	for (1..9) {
		$cal->item($_)->wrap_content(a({href=>"/events.pl?date=2002-01-0$_"}));
	}
	for (10..31) {
		$cal->item($_)->wrap_content(a({href=>"/events.pl?date=2002-01-$_"}));
	}
	print $cal->as_HTML;

	footer()
		unless $form->{plain};
}

createEnvironment();
main();
1;
