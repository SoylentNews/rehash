# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ScheduleShifts;

use strict;
use Date::Calc qw(Add_Delta_Days);
use DBIx::Password;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages);
use Slash::Utility;

use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

use constant SHIFT_DEFAULT		=> -2;
use constant SHIFT_NOTSET		=> -1;

our $VERSION = $Slash::Constants::VERSION;

our @DOW = qw(sun mon tue wed thu fri sat);
our %DOW;
$DOW{$DOW[$_]} = $_ for 0..$#DOW;

sub getDayOfWeekOffset {
	my($self, $day) = @_;
	if ($day =~ /\D/) {
		return $DOW{$day};
	} else {
		return $DOW[$day];
	}
}


sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'ScheduleShifts'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	my $static_shift_defs = getCurrentStatic('shift_definitions');

	# What about error handling for bad shift definitions?
	#
	# How about warnings for overlapping shifts, or should that
	# be allowed? Hmmmm.....	- Cliff
	for (split /:/, $static_shift_defs) {
		my($s_name, $s_times) = split /,/, $_;
		my($start, $len) = split /=/, $s_times;

		$self->{shift_defs}{$s_name} = {
			start	 => $start,
			'length' => $len,
		};
	}
	$self->{shift_types} = [ keys %{ $self->{shift_defs} } ];

	return $self;
}


sub getEditors {
	my($self) = @_;

	return $self->sqlSelectAllHashrefArray(
		'DISTINCT shifts.uid, nickname, realemail',
		'shifts, users',
		'shifts.uid = users.uid AND shifts.uid > 0'
	) || [];
}

sub getCurrentDefaultShifts {
	my($self) = @_;

	my($results, $returnable);

	# This should only pull records "from" January 1st thru 
	# January 7th. See the comments in saveDefaultShifts() for 
	# explanation.
	$results = $self->sqlSelectAllHashrefArray(
		'shift, uid, date_format(date, "%a") as dow', 
		'shifts', 'type="default"'
	);

	# Map into a more useful form.
	$returnable->{lc $_->{dow}}{$_->{'shift'}} = $_->{uid} for @{$results};

	return $returnable;
}


sub saveDefaultShifts {
	my($self, $defaults) = @_;

	my $form = getCurrentForm();

	# For default shifts, we are only concerned with the day of the 
	# week. To make things easier, we use the last year on which 
	# January 1st fell on a sunday in order to save these times.
	# So all records marked as "default" will fall between January 1st
	# and January 7th, 1995.
	my $new_defaults;
	for (keys %{$form}) {
		local $" = '|';
		$new_defaults->{$1}{$2} = $form->{$_}
			if /^(@DOW)_(.+)$/;
	}

	for my $wkday (keys %{$new_defaults}) {
		for my $s (keys %{$new_defaults->{$wkday}}) {
			next if	$defaults->{$wkday}{$s} == 
				$new_defaults->{$wkday}{$s};

			my $q_date = $self->sqlQuote(
				sprintf '%4d-%02d-%02d',
				Add_Delta_Days(
					1995, 1, 1,
					$self->getDayOfWeekOffset($wkday)
				)
			);

			my $s_q = $self->sqlQuote($s);
			$self->sqlDelete(
				'shifts',
				"type='default' AND date=$q_date AND
				 shift=$s_q"
			) if $defaults->{$wkday}{$s};
			$self->sqlInsert('shifts', {
				-date	=> $q_date,
				uid	=> $new_defaults->{$wkday}{$s},
				type	=> 'default',
				'shift'	=> $s,
			});

			$defaults->{$wkday}{$s} = $new_defaults->{$wkday}{$s};

			# Send message noting shift change.
			$self->sendShiftChangeMessage('default', {
				old     => $defaults->{$wkday}{$s},
				'new'   => $new_defaults->{$wkday}{$s},
				day     => $wkday,
				'shift' => $s,
			});
		}
	}
}


# Getting this data form the DB as opposed to the webheads is arguable, but
# in my opinion safer, since webhead times can shift and if the database time
# skews...well that really doesn't matter. What does matter is consistency,
# and these queries shouldn't put THAT much load on the database, and using
# its times should guarantee said consistency.
sub getCurrentWeek {
	my($self, $time) = @_;

	my $date = 'CURDATE()';

	if ($time && $time !~ /\D/) {
		my $new = $self->sqlSelect("FROM_UNIXTIME($time, '%Y-%m-%d')");
		$date = $self->sqlQuote($new) if $new;
	}

	my $returnable = $self->sqlSelect(
		"DATE_SUB($date, INTERVAL DAYOFWEEK($date)-1 DAY)"
	);

	return $returnable;
}


sub getCurrentGregorianWeek {
	my($self, $time) = @_;

	my $date = $self->sqlQuote( $self->getCurrentWeek($time) );

	my $returnable = $self->sqlSelect("TO_DAYS($date)");

	return $returnable;
}


sub getCurrentShifts {
	my($self, $nweeks, $time) = @_;

	my($results, $returnable);

	# First and last day of scheduling period.
	my $start = $self->sqlQuote($self->getCurrentWeek($time));
	my $ndays = $nweeks * 7 - 1;
	my $end = $self->sqlQuote($self->sqlSelect(
		"date_add(curdate(), interval $ndays day)"
	));

	$results = $self->sqlSelectAllHashrefArray(
		'shift, uid,
		 to_days(date_sub(date, interval dayofweek(date)-1 day))
		 as week,
		 date_format(date, "%a") as dow',
		'shifts', 
		"type='shift' AND date BETWEEN $start AND $end"
	);


	# Note that MySQL's to_days() uses the first day of 0 AD as a base
	# date, but Date::Calc::Add_Delta_Days uses the first day of *1 AD*
	# as a base, so we need to compensate when using the value of 
	# one with the other.
	for (@{$results}) {
		my $week = sprintf '%4d-%02d-%02d', 
			Add_Delta_Days(1, 1, 1, $_->{week} - 366);
		
		$returnable->{$week}{lc $_->{dow}}{$_->{'shift'}} = $_->{uid};
	}

	return $returnable;
}


sub saveCurrentShifts {
	my($self, $defaults) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();

	my $new_shifts;
	for (keys %{$form}) {
		local $" = '|';
		$new_shifts->{$1}{$2}{$3} = $form->{$_}
			if /^S_([\d\-]+)_(@DOW)_(.+)$/;
	}

	my $cur_shifts = $self->getCurrentShifts(
		$constants->{shift_schedule_weeks}
	);

	for my $sw (keys %{$new_shifts}) {
		$sw =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
		my($sy, $sm, $sdy) = ($1, $2, $3);
		for my $sd (keys %{$new_shifts->{$sw}}) {
			# $shift_date might not be necessary.
			my $shift_date = sprintf '%4d-%02d-%02d 00:00', 
				Add_Delta_Days(
					$sy, $sm, $sdy,
					$self->getDayOfWeekOffset($sd) 
				);
			for my $s (keys %{$new_shifts->{$sw}{$sd}}) {
				my $assigned = $new_shifts->{$sw}{$sd}{$s};
				my $current = $cur_shifts->{$sw}{$sd}{$s};
				my $default = $defaults->{$sd}{$s};

				next if	($current == $assigned)
				     || (!$current && $assigned == SHIFT_DEFAULT)
				     || (!$current && $assigned == $default);
	
				my $q_date = $self->sqlQuote($shift_date);
				if (!$current) {
					$self->sqlInsert('shifts', {
						uid	=> $assigned,
						type 	=> 'shift',
						shift	=> $s,
						date	=> $shift_date,
					});
				} else {
					my $s_q = $self->sqlQuote($s);
					my $where = <<EOT;
type='shift' AND date=$q_date AND shift=$s_q
EOT

					if ($assigned == $default || 
					    $assigned == SHIFT_DEFAULT) {
						$self->sqlDelete(
							'shifts', $where
						)
					} else {
						$self->sqlUpdate('shifts', 
							{ uid => $assigned },
							$where
						);
					}
				}
	
				# Write a message for shift change.
				$self->sendShiftChangeMessage('shift', {
					old     => $current || SHIFT_DEFAULT,
					'new'   => $assigned,
					day	=> $sd,
					date	=> $shift_date,
					'shift'	=> $s,
					default => $default,
						
					'Shift_Default' => SHIFT_DEFAULT,
					'Shift_Notset'  => SHIFT_NOTSET,
				});
			}
		}
	}
}

sub sendShiftChangeMessage {
	my($self, $type, $options) = @_;
	my $constants = getCurrentStatic();
	my $messages = getObject('Slash::Messages');
	my(%msg_data) = %{$options};

	# This may be rather squeamish, but I prefer to keep DB calls out
	# of templates.
	if ($options->{default}) {
		$msg_data{default_nickname} = ($options->{default} == SHIFT_NOTSET)
			? 'unassigned'
			: $self->getUser($options->{default}, 'nickname');
	}

	$msg_data{old_nickname} = ($options->{old} == SHIFT_DEFAULT)
		? $msg_data{default_nickname} # 'default'
		: ($options->{old} == SHIFT_NOTSET)
			? 'unassigned'
			: $self->getUser($options->{old}, 'nickname');

	$msg_data{new_nickname} = ($options->{'new'} == SHIFT_DEFAULT)
		? $msg_data{default_nickname} # 'default'
		: ($options->{'new'} == SHIFT_NOTSET)
			? 'unassigned'
			: $self->getUser($options->{'new'}, 'nickname');

	$msg_data{subject} = getData('shift_chg_subj', {
		type	=> $type,
		%msg_data,
	});
	
	# The people who receive this message:
	# 	- The person who had the old shift
	# 	- The person who has the new shift
	# 	- And any designated managers who don't match the 
	# 	  first two. For now, managers should be designated
	# 	  by UID.
	my @recipients;
	push @recipients, ($options->{old}, $options->{'new'})
		if $constants->{shift_change_message_users};
	for (split /,\s*/, $constants->{shift_change_managers}) {
		next if $_ < 0;
		push @recipients, $_ if /^\d+$/	&&
			$_ != $options->{old}	&&
			$_ != $options->{'new'};
	}

	if ($messages) {
		# Use site-based communications.
		$msg_data{template_name} = 'shift_change';
		$msg_data{template_page} = 'shifts';

		for (@recipients) {
			next unless $_ > 0;
			$messages->create(
				$_, MSG_CODE_SCHEDULECHG, \%msg_data
			) 
		}
	} else {
		# Email message outside of Slash::Messages
		# using Mail::Sendmail
		my $msg_body = slashDisplay('shift_change', {
			%msg_data,
		}, 1);
			
		for (@recipients) {
			next if $_ < 0;
			my $sendto = $self->getUser($_, 'realemail');

			sendEmail($sendto, $msg_data{subject}, $msg_body);
		}
	}
}


sub getShift {
	my($self, $when) = @_;
	$when ||= '';
	my $constants = getCurrentStatic();

	my $tzcode   = $constants->{shift_shifts_tz};

	# hr begin in our defined TZ, length in hours
	my @shifts = map {
		[ @{ $self->{shift_defs}{$_} }{qw(start length)} ]
	} @{ $self->{shift_types} };

	# we only need to find out needed week, day of week, and hour
	# if we need today/tomorrow/$x days, don't need hour

	my $fakeuser = { tzcode => $tzcode };
	setUserDate($fakeuser);

	my $time    = ($when =~ /^\d+$/) ? ($when || time()) : time();
	$time      += $fakeuser->{off_set};
	if (lc($when) =~ /^(-?\d+) (seconds?|minutes?|hours?)$/) {
		my($seconds, $unit) = ($1, $2);
		$seconds *= 60   if $unit =~ /^minutes?$/;
		$seconds *= 3600 if $unit =~ /^hours?$/;
		$time += $seconds;
	}
	if ($when =~ /^(-?\d+) seconds$/i) {
		$time += $1;
	}
	if ($when =~ /^(-?\d+) seconds$/i) {
		$time += $1;
	}
	my @time    = localtime($time);
	my $dow     = $time[6];
	my $day     = $self->getDayOfWeekOffset($dow);

	my(@slots, $days);

	if (lc($when) =~ /^(now|next|today|tomorrow|-?\d+ days?)$/) {
		$when = $1;
		if ($when =~ /^(-?\d+) days?$/) {
			$days = $1;
		} elsif ($when eq 'today') {
			$days = 0;
		} elsif ($when eq 'tomorrow') {
			$days = 1;
		}
	}

	if (defined $days) {
		if ($days) {
			$time += 86400 * $days;
			@time = localtime($time);
			$dow  = $time[6];
			$day  = $self->getDayOfWeekOffset($dow);
		}
		@slots = 0 .. $#{ $self->{shift_types} };
	} else {
		my $slot;
		my $hr = $time[2];
		# these two are same for 'now' or 'next'
		if ($hr < $shifts[0][0]) {
			$slot = 0;
		# XXX at some point, we should make it return "no current shift
		# holder", perhaps optionally?
		} elsif ($hr >= ($shifts[-1][0] + $shifts[-1][1])) {
			# go to first shift on next day
			$time += 86400;
			@time = localtime($time);
			$dow  = $time[6];
			$day  = $self->getDayOfWeekOffset($dow);
			$hr   = 0;
			$slot = 0;
		}

		unless (defined $slot) {
			for my $i (0 .. $#shifts) {
				my $shift = $shifts[$i];
				if ($hr >= $shift->[0] && $hr < ($shift->[0] + $shift->[1])) {
					$slot = $i;
				}
				last if defined $slot;
			}

			if ($when eq 'now') {
				# we have it
			} elsif ($when eq 'next') {
				if (++$slot > $#{ $self->{shift_types} }) {
					$time += 86400;
					@time = localtime($time);
					$dow  = $time[6];
					$day  = $self->getDayOfWeekOffset($dow);
					$hr   = 0;
					$slot = 0;
				}
			}
		}

		if (!defined $slot) {
			warn "how did we get here?  $hr!";
			$slot = 0;
		}

		@slots = $slot;
	}
	return($time, $day, \@slots);
}


sub getDaddy {
	my($self, $when) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my($time, $day, $slots) = $self->getShift($when);

	my $default = $self->getCurrentDefaultShifts;
	my $current = $self->getCurrentShifts($constants->{shift_schedule_weeks}, $time);
	my $week    = $self->getCurrentWeek($time);

	my @daddies = map {
		my $uid  = $_;
		my $u    = $slashdb->getUser($uid);
		my $data = {
			uid => $uid,
			
		};
		if ($uid > 0) {
			$data->{nickname}  = $u->{nickname};
			$data->{realemail} = $u->{realemail};
		}
		$data;
	} map {
		$current->{$week}{$day}{ $self->{shift_types}[$_] } ||
			$default->{$day}{ $self->{shift_types}[$_] }
	} @$slots;

	return \@daddies;
}

1;
