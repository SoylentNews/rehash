# This code is released under the GPL.
# Copyright 2001 by Brian Aker. See README
# and COPYING for more information, or see http://software.tangent.org/.
# $Id$

package Slash::Events;

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::DB::Utility;
use HTML::CalendarMonth;
use HTML::AsSubs;

use vars qw($VERSION @EXPORT);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Events'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getDatesBySid {
	my ($self, $sid) = @_;
	my $events = $self->sqlSelectAllHashrefArray(
		"*",
		"event_dates",
		" sid = '$sid'",
		" ORDER BY begin "
	);

	return $events;
}

sub getDayPrevious {
	my ($self, $date) = @_;
	return	
		unless $date;
	return $self->sqlSelect("DATE_ADD('$date', INTERVAL -1 DAY)");
}

sub getDayNext {
	my ($self, $date) = @_;
	return 
		unless $date;
	return $self->sqlSelect("DATE_ADD('$date', INTERVAL 1 DAY)");
}

sub setDates {
	my ($self, $sid, $begin, $end) = @_;
	$self->sqlDo("INSERT INTO event_dates (sid,begin,end) VALUES ('$sid', '$begin', '$end')");
}

sub minDate {
	my ($self, $sid) = @_;
	return $self->sqlSelect("MIN(begin)", 'event_dates', "sid = '$sid'" );
}

sub maxDate {
	my ($self, $sid) = @_;
	return $self->sqlSelect("MAX(end)", 'event_dates', "sid = '$sid'" );
}

sub deleteDates {
	my ($self, $id) = @_;
	$self->sqlDo("DELETE FROM event_dates WHERE id = $id");
}

sub getEventsByDay {
	my ($self, $date, $limit) = @_;

	my $user = getCurrentUser();
	my $section;
	$section ||= $user->{section};
	my $where = "((to_days('$date') >= to_days(begin)) AND (to_days('$date') <= to_days(end)))  AND stories.sid = event_dates.sid AND topics.tid = stories.tid";
	$where .= " AND stories.section = '$section'" if $section;
	my $order = "ORDER BY tid";
	$order .= " LIMIT $limit "
		if $limit;
	my $events = $self->sqlSelectAll(
		"stories.sid,title,'',topics.tid,alttext",
		"stories, event_dates, topics",
		$where,
		$order
		);
	
	return $events;
}

sub getEvents {
	my ($self, $date, $limit, $section, $topic)  = @_;

	my $user = getCurrentUser();
	$section ||= $user->{section};
	my $where = "(to_days('$date') <= to_days(begin)) AND stories.sid = event_dates.sid";
	$where .= " AND topics.tid = stories.tid";

	$where .= " AND stories.tid = $topic" if $topic;
	$where .= " AND stories.section = '$section'" if $section;

	my $order = "ORDER BY tid";
	$order .= " LIMIT $limit "
		if $limit;
	my $events = $self->sqlSelectAll(
		"stories.sid,title,time,begin,end,section,topics.tid,alttext",
		"stories, event_dates, topics",
		$where,
		$order
		);
	
	return $events;
}

sub getEventDaysBySidBox {
	my ($self, $sid) = @_;
	my $dates =  $self->getDatesBySid($sid);
	unless (@$dates) {
		$dates = "";
	}
	my $text = slashDisplay('eventsadmin', {
		dates 			=> $dates,
		sid 			=> $sid,
	}, { Return => 1});
	my $title = qq|Dates|;
	my $box = portalbox('', $title, $text);

	return $box;
}

sub createCal {
	my ($self, $month, $year) = @_;
	my $cal = HTML::CalendarMonth->new( month => $month, year => $year );
	$cal->item($cal->year, $cal->month)->attr(bgcolor => 'wheat');
	$cal->item($cal->year, $cal->month)->wrap_content(font({size => '+2'}));
	for (1..9) {
		$cal->item($_)->wrap_content(a({href=>"/events.pl?date=$year-$month-0$_"}));
	}
	for (10..31) {
		$cal->item($_)->wrap_content(a({href=>"/events.pl?date=$year-$month-$_"}))
			if $cal->item($_);
	}

	return $cal->as_HTML;
}


__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Events - Events system splace

=head1 SYNOPSIS

	use Slash::Events;

=head1 DESCRIPTION

This is the Events system for ExploitSeattle.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
