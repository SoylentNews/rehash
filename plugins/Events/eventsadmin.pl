#!/usr/bin/perl -w

use strict;
use Slash;
use Slash::Display;
use Slash::Events;
use Slash::Utility;

sub main {

	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $events   = getObject('Slash::Events');

	my $ops = {
	    edit     => {
		function => \&editEvent,
		seclev	=> 100,
	    },
	    'delete'	=> {
		function => \&editEvent,
		seclev	=> 100,
	    },
	    add	    => {
		function => \&editEvent,
		seclev	=> 100,
	    },
	    list    => {
		function => \&listEvents,
		seclev	=> 100,
	    },
	};
	

	my $op = lc($form->{op});
	chomp($op);
	print STDERR "op $op\n";
	$op = exists $ops->{$op} ? $op : 'list';

	print STDERR "op $op\n";
	redirect("/") 
		unless $user->{is_admin} || $user->{seclev} < $ops->{$op}{seclev};
	header();
	print createMenu('events');

	$ops->{$op}{function}->($slashdb, $constants, $user, $form, $events);

	footer();
}

##################################################################
sub editEvent {

	my ($slashdb,$constants,$user,$form,$events) = @_;

	if ($form->{op} eq 'delete') {
		$events->deleteDates($form->{id});
		print "Deleted event $form->{id} sid $form->{sid}<br>\n";
	} elsif ($form->{op} eq 'add') {
		$form->{end} ||= $form->{begin};
		$events->setDates($form->{sid} , $form->{begin}, $form->{end});
	}
	my $dates =  $events->getDatesBySid($form->{sid});
	my $title =  $events->getStory($form->{sid}, 'title');

	slashDisplay('editevent', {
		storytitle 		=> $title,
		dates 			=> $dates,
		sid 			=> $form->{sid},
	});
};

##################################################################
sub listEvents { 
	my ($slashdb,$constants,$user,$form,$events) = @_;

	if ($form->{month} && $form->{year} && $form->{day}) {
	    $form->{date} = $form->{year} . "/" . $form->{month} . "/" . $form->{day};
	}

	$form->{date} ||= timeCalc($slashdb->getTime(), '%Y-%m-%d');
	my $stories =  $events->getEvents($form->{date});

	my $days = [1 .. 31] ;

	my $months = $slashdb->getDescriptions('months');
	my $years = $slashdb->getDescriptions('years');
	my $day_selected = $form->{day} ? $form->{day} : int(timeCalc($slashdb->getTime(), '%d'));
	my $month_selected = $form->{month} ? $form->{month} : int(timeCalc($slashdb->getTime(),'%m'));
	my $year_selected = $form->{year} ? $form->{year} : timeCalc($slashdb->getTime(), '%Y');

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
				title		=> "$constants->{sitename} events",
				'link'		=> "$constants->{absolutedir}/",
			},
			image	=> 1,
			items	=> \@items
		});
	} else {
		if (@$stories) {
			# put this fucker in a template
			my $tmptitle = 'List Templates';
			slashDisplay('listevents', {
				title	=> $tmptitle,
				events	=> $stories,
				days	=> $days,
				months	=> $months,	    
				years	=> $years,
				month_selected => $month_selected,
				year_selected => $year_selected,
				day_selected => $day_selected,
			});
		} else {
			my $message = "Sorry, nothing found";
			print $message;
		}
	}


}

##################################################################

createEnvironment();
main();
1;
