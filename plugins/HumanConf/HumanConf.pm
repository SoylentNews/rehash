# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::HumanConf;

use strict;

use Captcha::reCAPTCHA;

use Slash;
use Slash::Utility::Environment;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub isInstalled {
	my($class) = @_;
	my $constants = getCurrentStatic();
	return 0 if ! $constants->{hc};
	return $class->SUPER::isInstalled();
}

sub _formnameNeedsHC {
        my($self, $formname, $options) = @_;            
	return 1 if $options->{needs_hc};
	my $regex = getCurrentStatic('hc_formname_regex') || '^comments$';
        return 1 if $formname =~ /$regex/;
        return 0;
}

sub createFormkeyHC {
	my($self, $formname, $options) = @_;

	# Only certain formnames need human confirmation.  From any       
	# other formname, just return 1, meaning everything is ok
	# (no humanconf necessary).
	return 'ok' if !$self->_formnameNeedsHC($formname, $options);

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $formkey = $options->{frkey} || $form->{formkey};
	return 0 unless $formkey;

	my $c = Captcha::reCAPTCHA->new;

	# MC: Bah, this crap is annoying, this entire module needs a rewrite
	# Think some places check for hcid
	$user->{state}{hcid} = 1;
	$user->{state}{hc} = 1;
	$user->{state}{hcinvalid} = 0;
	$user->{state}{hcquestion} = $question;
	$user->{state}{hchtml} = $c->get_html("6LcksO4SAAAAAL4eWMr0fB5lSRdvy2xyhciGJhYt");
	return 1;
}

sub reloadFormkeyHC {
	my($self, $formname, $options) = @_;

	my $user = getCurrentUser();

	# Only certain formnames need human confirmation.  Other formnames
	# won't even have HC data created for them, so there's no need to
	# waste time hitting the DB.
	if (!$self->_formnameNeedsHC($formname, $options)) {
		$user->{state}{hc} = 0;
		return;
	}
	$user->{state}{hc} = 1;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $formkey = $options->{frkey} || $form->{formkey};

	my $c = Captcha::reCAPTCHA->new;
	my $hcanswer = $form->{hcanswer};
	my $hclastanswer = $form->{hclastanswer};
	my $success = 0;
	if ($options->{check_answer} && $hcid && $hcanswer) {
		if ($hclastanswer && $hcanswer eq $hclastanswer) {
			$success = $form->{hcsuccess};
		} else {
			if ($self->_checkFormkeyHC($hcid, $hcanswer, $answer)) {
				$success = 1;
			} else {
				$tries_left--;
			}
		}
	}

	# MC: Tries disabled for the moment
	# Probabl can just let reCAPTCHA handle this 
	#if ($tries_left) {

	# If we get down here, then we need to redisplay the reCAPTCHA
	
	$user->{state}{hcinvalid} = 0;
	$user->{state}{hcquestion} = $question;
	$user->{state}{hchtml} = $c->get_html("6LcksO4SAAAAAL4eWMr0fB5lSRdvy2xyhciGJhYt");

	$user->{state}{hcsuccess} = 1 if $success;
	$user->{state}{hclastanswer} = $hcanswer if $hcanswer;
	#} else {
	#	$user->{state}{hcinvalid} = 1;
	#	$user->{state}{hcerror} = getData('nomorechances', {}, 'humanconf');
	#}
	return !$user->{state}{hcinvalid};
}

sub validFormkeyHC {
	my($self, $formname, $options) = @_;

	# Only certain formnames need human confirmation.  Other formnames
	# won't even have HC data created for them, so there's no need to
	# waste time hitting the DB.
	return 'ok' if !$self->_formnameNeedsHC($formname, $options);

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $formkey = $options->{frkey} || $form->{formkey};
	return 'invalidhc' unless $formkey;

	my $formkey_quoted = $slashdb->sqlQuote($formkey);

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
        return 'ok' if $self->_checkFormkeyHC($hcid, $form->{hcanswer}, $answer);
	return $tries_left > 1 ? 'invalidhcretry' : 'invalidhc';
}


sub _checkFormkeyHC {
	my($self, $hcid, $hcanswer, $answer) = @_;
        if ($hcanswer && lc($hcanswer) eq lc($answer)) {
		# Correct answer submitted.
                return 1;
        }

	my $slashdb = getCurrentDB();
	# Incorrect answer, but user may be able to keep trying.
	$slashdb->sqlUpdate(
		"humanconf",
		{ -tries_left => "tries_left - 1" },
		"hcid=$hcid"
	);
	return 0;
}

1;
