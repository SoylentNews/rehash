#!/usr/bin/perl -w

# Big note by me, this breaks our conventions because I
# want to see how it works for a bit and if its the best
# way to go about this. When I feel that its closer to being
# done I will API it. -Brian

use strict;

use vars qw( %task $me );
use Slash::Constants qw( :people );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '7 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	slashdLog('Rebuilding People Beginning ');
	my $users = $slashdb->sqlSelectColArrayref('uid', 'people');

	for my $uid (@$users) {
		my $people = $slashdb->setUser($uid, 'people ');
		# We clean out everuthing but friend and foe
		for (keys %$people) {  
			delete $people->{$_} 
				unless $people->{$_} == FRIEND || $people->{$_} == FOE;
		}
		# The raw SQL code I decided on -Brian
		# select b.person from people as a, people as b WHERE a.uid=986 AND a.type="friend" AND b.uid = a.person;
		my $fof = $slashdb->sqlSelectColArrayref('b.person', 'people as a, people as b', "a.uid=$uid AND a.type='friend' AND b.uid=a.person AND b.person!=$uid");
		my $eof = $slashdb->sqlSelectColArrayref('b.person', 'people as a, people as b', "a.uid=$uid AND a.type='foe' AND b.uid=a.person AND b.person!=$uid");
		my $fans = $slashdb->getFans($_);
		my $freaks = $slashdb->getFreaks($_);
		# FOF and EOF never override friends or foes -Brian
		for (@$fans) {
			$people->{$_} = FAN
				unless $people->{$_};
		}
		for (@$freaks) {
			$people->{$_} = FREAK
				unless $people->{$_};
		}
		for (@$fof) {
			$people->{$_} = FOF
				unless $people->{$_};
		}
		for (@$eof) {
			$people->{$_} = EOF
				unless $people->{$_};
		}
		$slashdb->setUser($uid, { people => $people });
		
	}

	slashdLog('Rebuilding People Ending ');

	return ;
};

1;

