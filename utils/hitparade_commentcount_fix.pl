#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use vars qw( %task );
use FindBin '$Bin';
use File::Basename;
use Slash;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Getopt::Std;

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
#my $PROGNAME = basename($0);
my $PROGNAME = 'hitparade_commentcount_fix.pl';
(my $PREFIX = $Bin) =~ s|/[^/]+/?$||;

$task{$PROGNAME}{timespec} = '0,5,10,15,20,25,30,35,40,45,50,55 * * * *';

# Handles mail and administrivia necessary for RECENTLY expired users.
$task{$PROGNAME}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $counts = $slashdb->sqlSelectAll('sid,commentcount', 'discussions', " sid != ''");
	for(@$counts) {
		$slashdb->sqlDo(" UPDATE stories SET commentcount='$_->[1]' WHERE sid='$_->[0]'");
	}

	my $hits = $slashdb->sqlSelectAll('discussions.id,threshold,count,sid', 'discussion_hitparade, discussions', " discussions.id=discussion_hitparade.discussion AND  sid != '' AND type ='open' ");
	
	my $hitparade;
	my $sid2discussion;
	for(@$hits){
		$hitparade->{$_->[0]}{$_->[1]} = $_->[2];
		$sid2discussion->{$_->[0]} = $_->[3]
			if $_->[3];
	}

	for (keys %$hitparade) {
		my $discussion = $hitparade->{$_};
		my $sid = $sid2discussion->{$_};
		# Ok, its a hack, move along, this is not the code you are looking for -Brian
		my $string = join (",",
				map { $discussion->{$_} || 0 }
				($constants->{comment_minscore} .. $constants->{comment_maxscore})
		);

		$slashdb->sqlDo(" UPDATE discussions SET hitparade ='$string' WHERE sid='$_'");
		$slashdb->sqlDo(" UPDATE stories SET hitparade ='$string' WHERE sid='$sid'")
				if $sid;
	}
};


# Standalone code.
if ($0 =~ /$PROGNAME$/) {
	my(%opts);

	getopts('hu:v', \%opts);
	if (exists $opts{h} || !exists $opts{u}) {
		print <<EOT;

Usage: $PROGNAME -u [virtual user]

	This program rebuilds the story and discussion tables data for
	hitparade and commentcount. This is normally taken care of
	by slashd so odds are you will never need this program.
EOT

		exit 1;
	} elsif (exists $opts{v}) {
		print "(slashd task) $PROGNAME $VERSION.\n\n";
	}

	createEnvironment($opts{u});
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	# Calls the code defined above.
	$task{$PROGNAME}{code}->($opts{u}, $constants, $slashdb);
}


1;
