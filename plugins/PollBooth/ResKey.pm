# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::PollBooth::ResKey;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our $VERSION = $Slash::Constants::VERSION;

sub doCheck {
	my($self) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	if ($user->{is_anon} && !$constants->{allow_anon_poll_voting}) {
		return(RESKEY_DEATH, ['anon', {}, 'pollBooth']);
	}

	my $qid = $self->opts->{qid};

	return(RESKEY_DEATH, ['no qid', {}, 'pollBooth']) unless $qid;

	# Pudge: I assume it's OK to use a reader DB here...? - Jamie
	my $pollbooth_reader = getObject('Slash::PollBooth', { db_type => 'reader' });
	return(RESKEY_DEATH, ['no polls', {}, 'pollBooth']) unless $pollbooth_reader;
	if ($pollbooth_reader->checkPollVoter($qid, $user->{uid})) {
		return(RESKEY_DEATH, ['already voted', {}, 'pollBooth']);
	}

	return RESKEY_SUCCESS;
}

1;
