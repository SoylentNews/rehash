# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::HumanConf;

use strict;
#use GD;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return undef unless $plugins->{HumanConf};

	my $constants = getCurrentStatic();
	return undef unless $constants->{hc};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

sub _formnameNeedsHC {
        my($self, $formname) = @_;            
	my $regex = getCurrentStatic('hc_formname_regex') || '^comments$';
        return 1 if $formname =~ /$regex/;
        return 0;
}

sub createFormkeyHC {
	my($self, $formname) = @_;

	# Only certain formnames need human confirmation.  From any       
	# other formname, just return 1, meaning everything is ok
	# (no humanconf necessary).
	return 'ok' if !$self->_formnameNeedsHC($formname);

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $formkey = $form->{formkey};
	return 0 unless $formkey;

	# Decide which question we're asking.
	my $hcqid = $user->{hcqid}
		|| $constants->{humanconf_default_question}
		|| 1;
	my($question) = $slashdb->sqlSelect(
		"question",
		"humanconf_questions",
		"hcqid=$hcqid"
	);

	# Loop until we successfully get an answer/html pair (one time
	# in a zillion we'll have to try more than once).
	my $secs = $constants->{hc_pool_secs_before_use} || 3600;
	my($hcpid, $html) = ('', '');
	while (1) {

		# Grab a random answer/html for that question.
		($hcpid, $html) = $slashdb->sqlSelect(
			"hcpid, html",
			"humanconf_pool",
			"hcqid=" . $slashdb->sqlQuote($hcqid)
				. " AND filename != ''"
				. " AND created_at < DATE_SUB(NOW(), INTERVAL $secs SECOND)"
				. " AND inuse = 0",
			"ORDER BY RAND() LIMIT 1"
		);
		if (!$hcpid) {
			warn "HumanConf warning: empty humanconf_pool"
				. " for question $hcqid";
			return 0;
		}

		# Touch that entry in the pool so the task doesn't delete
		# it while the user is using it.
		my $touched = $slashdb->sqlUpdate(
			"humanconf_pool",
			{ -lastused => 'NOW()' },
			"hcpid=$hcpid"
		);
		last if $touched;

		# If it was deleted between the previous two SQL
		# statements, repeat the loop (and don't go skydiving
		# today, geez what terrible luck).

	}

	# Create an entry in the humanconf table associating the
	# already-created formkey with this answer/html.
	my $success = $slashdb->sqlInsert("humanconf", {
		hcpid	=> $hcpid,
		formkey	=> $formkey,
	});
	return 0 unless $success;
	my $hcid = $slashdb->getLastInsertId();

	$user->{state}{hcid} = $hcid; # for debugging
	$user->{state}{hc} = 1;
	$user->{state}{hcinvalid} = 0;
	$user->{state}{hcquestion} = $question;
	$user->{state}{hchtml} = $html;
	return 1;
}

sub reloadFormkeyHC {
	my($self, $formname) = @_;

	my $user = getCurrentUser();

	# Only certain formnames need human confirmation.  Other formnames
	# won't even have HC data created for them, so there's no need to
	# waste time hitting the DB.
	if (!$self->_formnameNeedsHC($formname)) {
		$user->{state}{hc} = 0;
		return ;
	}
	$user->{state}{hc} = 1;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $formkey = $form->{formkey};
	my $formkey_quoted = $slashdb->sqlQuote($form->{formkey});

	my($hcid, $html, $question, $tries_left) = $slashdb->sqlSelect(
		"hcid, html, question, tries_left",
		"humanconf, humanconf_pool, humanconf_questions",
		"humanconf.formkey = $formkey_quoted
		 AND humanconf_pool.hcpid = humanconf.hcpid
		 AND humanconf_questions.hcqid = humanconf_pool.hcqid"
	);
	if ($tries_left) {
		$user->{state}{hcinvalid} = 0;
		$user->{state}{hcquestion} = $question;
		$user->{state}{hchtml} = $html;
	} else {
		$user->{state}{hcinvalid} = 1;
		$user->{state}{hcerror} = getData('nomorechances', {}, 'humanconf');
	}
}

sub validFormkeyHC {
	my($self, $formname) = @_;

	# Only certain formnames need human confirmation.  Other formnames
	# won't even have HC data created for them, so there's no need to
	# waste time hitting the DB.
	return 'ok' if !$self->_formnameNeedsHC($formname);

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $formkey = $form->{formkey};
	return 'invalidhc' unless $formkey;

	my $formkey_quoted = $slashdb->sqlQuote($form->{formkey});

	# If this formkey is valid, and there is a corresponding humanconf
	# entry, check that as well.  Note that if there is an hcid in the 
	# form, we can't trust it, because the user might edit/delete it;              
	# we have to hit the table to see if there's a humanconf entry for              
	# this formkey.
        my($hcid, $hcpid, $tries_left, $answer) = $slashdb->sqlSelect(     
                "hcid, humanconf.hcpid, tries_left, answer",
                "humanconf, humanconf_pool",
                "humanconf.formkey = $formkey_quoted
                 AND humanconf_pool.hcpid = humanconf.hcpid
		 AND tries_left > 0"      
        );
        if (!$hcid) {
                # No humanconf associated with this formkey.  Either there
		# is a bug somewhere or the answer has had its tries all
		# wasted by previous incorrect answers.
                return 'invalidhc';
        }
        if ($form->{hcanswer} && $form->{hcanswer} eq $answer) {
		# Correct answer submitted.
                return 'ok';
        }
	# Incorrect answer, but user may be able to keep trying.
	$slashdb->sqlUpdate(
		"humanconf",
		{ -tries_left => "tries_left - 1" },
		"hcid=$hcid"
	);
	return $tries_left > 1 ? 'invalidhcretry' : 'invalidhc';
}

