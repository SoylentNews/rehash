#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Slash::Email - web script
# 
# Email a Slash site story to a friend!
# (c) OSDN 2002

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Display;
use Slash::Utility;
use Email::Valid;
use HTML::Entities;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


# this is an example main().  feel free to use what you think
# works best for your program, just make it readable and clean.

sub main {
	my $slashdb	= getCurrentDB();
	my $constants	= getCurrentStatic();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();

	# Primary fields.
	my $sid		= $form->{sid};
	my $email	= $form->{email};

	# Use for ops where anonymous access is optional.
	my $allow_anon =
		$constants->{email_allow_anonymous} || !$user->{is_anon};

	my($fk_gen, $fk_save) = (
		[ 'generate_formkey' ],
		[ qw(
			max_post_check
			valid_check
			formkey_check
		)],
	);

	my $ispost = $user->{state}{post};
	my $default = 'email_form';
	my $ops = {
		email_form	=> {
			allowed		=> $allow_anon,
			function	=> \&emailStoryForm,
			formkey		=> $fk_gen,
			form		=> 'email_form',
		},
		email_send	=> {
			allowed		=> $allow_anon && $ispost,
			function	=> \&emailStory,
			formkey		=> $fk_save,
			form		=> 'email_form',
		},

		optout_form	=> {
			allowed		=> 1,
			function	=> \&emailOptoutForm,
			formkey		=> $fk_gen,
			form		=> 'optout_form',
		},
		optout_save	=> {
			allowed		=> $ispost,
			function	=> \&emailOptout,
			formkey		=> $fk_save,
			form		=> 'optout_form',
		},

		optoutrem_form	=> {
			allowed		=> $user->{is_admin},
			function	=> \&removeOptoutForm,
		},

		optoutrem	=> {
			allowed		=> $user->{is_admin} && $ispost,
			function	=> \&removeOptout,
		},
	};

	# prepare op to proper value if bad value given
	my $op = $form->{op};
	if (!$op || !exists $ops->{$op} || !$ops->{$op}{allowed}) {
		$op = $default;
	}

	header(getData('header'));

	# Instantiate plugin.
	my $Email;
	unless ($Email = getObject('Slash::Email')) {
		print getData('plugin_not_installed');
		footer();
		return;
	}

	my($fk_error, $fk_check);
	if ($ops->{$op} && ref $ops->{$op}{formkey} eq 'ARRAY') {
		for (@{$ops->{$op}{formkey}}) {
			next unless $_;
			# Need to ASSIGN $fk_check because $_ is empty at
			# loop's end.
			last if $fk_error =
				formkeyHandler(
					$fk_check = $_,
					'Email-' . $ops->{$op}{form},
					$form->{formkey},
					undef,
					{ no_hc => 1 }
				);
		}
	}

	unless ($fk_error) {
		# dispatch of op
		$ops->{$op}{function}->(
			$slashdb, 
			$constants, 
			$user, 
			$form,
			$Email
		);
	} else {
		print getData('formkeyError', {
			operation	=> $op,
			check		=> $fk_check,
		});
	}

	writeLog("email.pl: $op $email $sid");
	footer();
}

sub emailStoryForm {
	my($slashdb, $constants, $user, $form) = @_;

	my $story;
	$story = $slashdb->getStory($form->{sid}) if $form->{sid};

	slashDisplay('emailStoryForm', { story => $story });
}

sub emailStory {
	my($slashdb, $constants, $user, $form, $Email) = @_;

	# Check input for valid RFC822 email address.
	my $email = decode_entities($form->{email});
	if (!Email::Valid->rfc822($email)) {
		print getData('invalid_email');
		return;
	}

	# Check for address in opt-out list.
	if ($Email->checkOptoutList($email)) {
		print getData('optout_email');
		return;
	}

	# Retrieve story and all information necessary for proper display.
	my $story = $slashdb->getStory($form->{sid});

	# Format story.
	#
	# Preprocess story fields for display.
	1 while chomp($story->{introtext});
	1 while chomp($story->{bodytext});
	$story->{introtext} = parseSlashizedLinks($story->{introtext});
	$story->{bodytext} =  parseSlashizedLinks($story->{bodytext});

	# Convert story to ASCII and grab all HREF data from "A" tags.
	($story->{asciitext}, @{$story->{links}}) = html2text(
		"$story->{introtext}\n\n$story->{bodytext}",
		74
	);

	$story->{formatted_text} = slashDisplay('dispStory', {
		story	=> $story,
	}, { Return => 1, Nocomm => 1 });
	
	# E-mail story.
	my $subject = getData('email_subject', { story => $story });
	my $rc = sendEmail($email, $subject, $story->{formatted_text});
	print getData('mail_result', { code => $rc });
}

sub emailOptoutForm {
	my($slashdb, $constants, $user, $form) = @_;

	slashDisplay('emailOptoutForm');
}

sub emailOptout {
	my($slashdb, $constants, $user, $form, $Email) = @_;

	my $email = decode_entities($form->{email});
	if (Email::Valid->rfc822($email)) {
		# Send final confirmation email to the address being removed
		# as another form of abuse protection.
		my $content = slashDisplay('optout_confirm', 0, {
			Return => 1, NoComm => 1
		});
		my $subject = getData('optout_confirm_subject');
		my $rc = sendEmail($email, $subject, $content);
		# If we bomb the attempt to send the final mail, we may have
		# been fed a bogus address. Only remove from list if the
		# email was successfully sent.
		$Email->addToOptoutList($email) if $rc;
		print getData('optout_added', { result => $rc });
	} else {
		print getData('invalid_email');
	}
}

sub removeOptoutForm {
	my($slashdb, $constants, $user, $form) = @_;

	slashDisplay('removeOptoutForm');
}

sub removeOptout {
	my($slashdb, $constants, $user, $form, $Email) = @_;

	my $email = decode_entities($form->{email});
	my $rc = $Email->removeFromOptoutList($form->{email});
	print getData('optout_removed', { result => $rc });

	removeOptoutForm(@_);
}

# MAIN LOOP
createEnvironment();
main();

1;
