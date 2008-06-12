# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::TagModeration;

use strict;

use Slash;
use Slash::Utility;
use Slash::DB::Utility;
use Slash::Display;

our $VERSION = $Slash::Constants::VERSION;

# most of the guts are now in Slash::Moderation, and we inherit it all ...
use base 'Slash::Moderation';

# ... except for this function, which is manually imported ...
*ajaxModerateCid = \&Slash::Moderation::ajaxModerateCid;

# ... and these three methods.
sub removeModTags {
	my($self, $uid, $cid) = @_;

	my $comment_globjid = $self->getGlobjidFromTargetIfExists('comments', $cid);
	if ($comment_globjid) {
		my $tagsdb = getObject('Slash::Tags');
		$tagsdb->deactivateTag({ globjid => $comment_globjid, uid => $uid });
	}

}

sub createModTag {
	my($self, $uid, $cid, $reason) = @_;

	my $reasons = $self->getReasons;
	my $reason_name = lc $reasons->{$reason}{name};
	my $tagsdb = getObject('Slash::Tags');
	my $created = $tagsdb->createTag({
		table   => 'comments',
		id      => $cid,
		uid     => $uid,
		name    => $reason_name,
		private => 1,
	});

#print STDERR "TagModeration::createModeratorLog ret_val=$ret_val reason_name='$reason_name' created='$created'\n";
}

sub setModPoints {
	my($self, $uids, $granted, $opts) = @_;
	my $constants = getCurrentStatic();

	my($num_high, $sum_high, @high_uids) = (0, 0);
	for my $uid (@$uids) {
		next unless $uid;
		my $user = $self->getUser($uid);
		my @clouts = grep { $_ } values %{ $user->{clout} };
		my $high_clout = $constants->{m1_pointgrant_highclout} || 4;
		my $high_clout_count = scalar grep { $_ > $high_clout } @clouts;
		if ($high_clout_count > 0) {
			$num_high++;
			$sum_high += $high_clout_count;
			push @high_uids, $uid;
		}
		my $this_pointgain = $opts->{pointtrade} * (1 + $high_clout_count);
		my $this_maxpoints = $opts->{maxpoints}  * (1 + $high_clout_count);
		my $rows = $self->setUser($uid, {
			-lastgranted    => 'NOW()',
			-tokens         => "GREATEST(0, tokens - $opts->{tokentrade})",
			-points         => "LEAST(points + $this_pointgain, $this_maxpoints)",
		});
		$granted->{$uid} = 1 if $rows;
	}
	main::slashdLog("convert_tokens_to_points num_high=$num_high sum_high=$sum_high high_uids='@high_uids'");
}


1;

