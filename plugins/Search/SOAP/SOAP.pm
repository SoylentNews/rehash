# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Search::SOAP;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# As a note I will be adding support for sort later.
# I want to make it easy for people just to pass in a string
# for query, which is why it is the first param -Brian
#################################################################
# This will be removed later and put into vars -Brian
sub MAX_NUM {
	return 15;
}

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Search'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

####################################################################################
sub findComments {
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
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
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
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
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
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
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
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
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
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
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
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
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findRSS($options, 0, MAX_NUM);
	}

	return $answers;
}

####################################################################################
sub findDiscussion {
	my($query, $options) = @_;
	$options->{query} = $query;

	my($slashdb, $searchDB) = Slash::Search::SelectDataBases();
	my $constants = getCurrentStatic();

	my $answers;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		return;
	} else {
		$answers = $searchDB->findDiscussion($options, 0, MAX_NUM);
	}

	return $answers;
}

#################################################################
sub DESTROY {
}



1;
