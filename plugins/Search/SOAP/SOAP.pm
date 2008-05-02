# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Search::SOAP;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use base 'Slash::DB::Utility';

our $VERSION = $Slash::Constants::VERSION;

# As a note I will be adding support for sort later.
# I want to make it easy for people just to pass in a string
# for query, which is why it is the first param -Brian
#################################################################
# This will be removed later and put into vars -Brian
sub MAX_NUM {
	return 15;
}

####################################################################################
sub findComments {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findComments($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findUsers {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findUsers($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findStory {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findStory($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findJournalEntry {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findJournalEntry($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findPollQuestion {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findPollQuestion($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findSubmission {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findSubmission($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findRSS {
	my($self, $query, $options) = @_;
	$options->{query} = $query;

	my $slashdb = getCurrentDB();
	my $searchDB = getObject('Slash::Search', { db_type => 'search' });
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findRSS($options, 0, MAX_NUM);
	}

	return $answers;
}

#################################################################
sub DESTROY {
}



1;
