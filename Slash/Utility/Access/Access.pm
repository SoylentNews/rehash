# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Utility::Access;

=head1 NAME

Slash::Utility::Access - SHORT DESCRIPTION for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	# do not use this module directly

=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Digest::MD5 'md5_hex';
use Slash::Display;
use Slash::Utility::Data;
use Slash::Utility::Environment;
use Slash::Utility::System;
use Slash::Constants qw(:web :people :messages);

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT	   = qw(
	checkFormPost
	formkeyError
	formkeyHandler
	compressOk
	filterOk
	getFormkey
	submittedAlready
	allowExpiry
	setUserExpired
	intervalString
	isDiscussionOpen
);

# really, these should not be used externally, but we leave them
# here for reference as to what is in the package
# @EXPORT_OK = qw(
# 	intervalString
# );

#========================================================================

=head2 getFormkey()

Creates a random formkey (well, as random as random gets)

=over 4

=item Return value

Return a random value based on alphanumeric characters

=back

=cut

sub getFormkey {
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $formkey;
#	my $count = 0;

	# for now I am leaving the formkey error code in.  it should
	# never print, except maybe once in a blue moon, so it doesn't
	# hurt anything. -- pudge
	# Duplicate formkeys are now tested for in createFormkey(),
	# leaving this function pretty small. -- jamie, 2002/04/15

#	while (!$formkey || $slashdb->existsFormkey($formkey)) {
#		if ($formkey) {
#			if (++$count > 50) {
#				print STDERR "get formkey failed (count:$count) ",
#					"$user->{uid}/ipid:$user->{ipid}\n";
#				return "a" x 10;
#			}
#
#			print STDERR "$formkey already exists (count:$count) ",
#				"$user->{uid}/ipid:$user->{ipid}\n";
#		}
		$formkey = getAnonId(1);
#	}

	# only print if we previously failed or something
#	print STDERR "$formkey is good! (count:$count) ",
#		"$user->{uid}/ipid:$user->{ipid}\n" if $count > 0;
	return $formkey;
}

#========================================================================

=head2 formkeyError()

generates proper error message based on formkey error and 
also logs to abuse log if the error warrants it

=over 4

=item Return value

Returns an error message to be printed out by calling script

=back

=cut

sub formkeyError {
	my($value, $formname, $limit, $nocomm) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	$formname =~ s|/\w+$||;  # remove /nu, /mp, etc.

	my $abuse_reasons = { usedform => 1, invalid => 1, maxposts => 1,
		invalidhc => 1 };
	my $hashref = {};

	if ($value eq 'response' || $value eq 'speed' || $value eq 'fkspeed') {
		if ($value eq 'fkspeed') {
			$value = 'speed';
			$hashref->{attempt} = 1;
		}
		$hashref->{limit} = intervalString($constants->{"${formname}_${value}_limit"});

		# limit in this case is the interval 
		$hashref->{interval} = intervalString($limit) if $limit;
		$hashref->{value} = $formname . "_" . $value;

	} elsif ($value eq 'unused') {
		$hashref->{limit} = $limit;	
		$hashref->{value} = $formname . "_" . $value;
	
	} elsif ($value eq 'invalid'
		|| $value eq 'invalidhc'
		|| $value eq 'invalidhcretry'
		|| $value eq 'invalid-bare'
		|| $value eq 'invalidhc-bare'
		|| $value eq 'invalidhcretry-bare') {
		$hashref->{formkey} = $form->{formkey};
		$hashref->{value} = $value;

	} elsif ($value eq 'maxposts' || $value eq 'maxposts-bare') {
		$hashref->{limit} = $limit;	
		$hashref->{interval} = intervalString($constants->{formkey_timeframe});
		$hashref->{value} = $formname . "_" . $value;

	} elsif ($value eq 'maxreads') {
		$hashref->{limit} = $limit;	
		$hashref->{interval} = intervalString($constants->{formkey_timeframe});
		$hashref->{value} = $formname . "_" . $value;

	} elsif ($value eq 'usedform') {
		if (my $interval = $slashdb->getFormkeyTs($form->{formkey},1)) {
			$hashref->{interval} = intervalString( time() - $interval );
		}
		$hashref->{value} = $value;
	} elsif ($value eq 'cantinsert') {
		$hashref->{value} = $value;
	}

	if ($abuse_reasons->{$value}) {
		# this is to keep from overwriting $hashref, since
		# $hashref->{value} has already been set
		my $tmpvalue = $hashref->{value};
		$hashref->{no_error_comment} = 1;
		$hashref->{value} = 'formabuse_' . $value;
		$hashref->{formname} = $formname; 
		$hashref->{formkey} = $form->{formkey}; 

		my $error_message = slashDisplay('formkeyErrors', $hashref, 
			{ Return => 1, Nocomm => 1 });

		$slashdb->createAbuse($error_message, $formname, $ENV{QUERY_STRING}, 
			$user->{uid}, $user->{ipid}, $user->{subnetid} );

		# set it back
		$hashref->{value} = $tmpvalue; 
	}

	return slashDisplay('formkeyErrors', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}
## NEED DOCS
#========================================================================
sub intervalString {
	# Ok, this isn't necessary, but it makes it look better than saying:
	#  "blah blah submitted 23333332288 seconds ago"
	my($interval) = @_;
	my $interval_string;

	if ($interval > 60) {
		my($hours, $minutes) = 0;
		if ($interval > 3600) {
			$hours = int($interval/3600);
			if ($hours > 1) {
				$interval_string = $hours . ' ' . Slash::getData('hours', '', '');
			} elsif ($hours > 0) {
				$interval_string = $hours . ' ' . Slash::getData('hour', '', '');
			}
			$minutes = int(($interval % 3600) / 60);

		} else {
			$minutes = int($interval / 60);
		}

		if ($minutes > 0) {
			$interval_string .= ", " if $hours;
			if ($minutes > 1) {
				$interval_string .= $minutes . ' ' . Slash::getData('minutes', '', '');
			} else {
				$interval_string .= $minutes . ' ' . Slash::getData('minute', '', '');
			}
		}
	} else {
		$interval_string = $interval . ' ' . Slash::getData('seconds', '', '');
	}

	return $interval_string;
}

#========================================================================
sub formkeyHandler {
	# ok, I know we don't like refs, but I don't wanna rewrite the 
	# whole damned system


	my($formkey_op, $formname, $formkey, $message_ref, $options) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $error_flag = 0;
	my $msg = '';

	$formname	||= $user->{currentPage};
	$formkey	||= $form->{formkey};

	if ($formkey_op eq 'max_reads_check') {
		if (my $limit = $slashdb->checkMaxReads($formname)) {
			$msg = formkeyError('maxreads', $formname, $limit);
			$error_flag = 1;
                }
	} elsif ($formkey_op eq 'max_post_check') {
		if (my $limit = $slashdb->checkMaxPosts($formname)) {
			if ($options->{fk_bare_errors}) {
				$msg = formkeyError('maxposts-bare', $formname, $limit);
			} else {
				$msg = formkeyError('maxposts', $formname, $limit);
			}
			$error_flag = 1;
		}
	} elsif ($formkey_op eq 'update_formkeyid') {
		$slashdb->updateFormkeyId($formname, $formkey, $user->{uid}, $form->{rlogin}, $form->{upasswd});
	} elsif ($formkey_op eq 'valid_check') {
		my $valid = $slashdb->validFormkey($formname, $options);
		if ($valid eq 'ok') {
			# All is well.
		} else {
			if ($options->{fk_bare_errors}) {
				$msg = formkeyError($valid . '-bare', $formname);
			} else {
				$msg = formkeyError($valid, $formname);
			}

			if ($valid eq 'invalidhcretry'
				|| $valid eq 'invalidhc') {
				# It's OK, the user can retry.
				$error_flag = -1;
			} else {
				# No retries from 'invalid'
				$error_flag = 1;
			}
		}
	} elsif ($formkey_op eq 'response_check') {
		if (my $interval = $slashdb->checkResponseTime($formname)) {
			$msg = formkeyError('response', $formname, $interval);
			$error_flag = 1;
		}
	} elsif ($formkey_op eq 'interval_check') {
		# check interval from this attempt to last successful post
		if (my $interval = $slashdb->checkPostInterval($formname)) {	
			$msg = formkeyError('speed', $formname, $interval);
			# give the user a preview form so they can post after time limit
			$error_flag = -1;
		}
	} elsif ($formkey_op eq 'formkey_check') {
		# check if form already used
		unless (my $increment_val = $slashdb->updateFormkeyVal($formname, $formkey)) {
			if ($options->{fk_bare_errors}) {
				$msg = formkeyError('usedform-bare', $formname);
			} else {
				$msg = formkeyError('usedform', $formname);
			}
			$error_flag = 1;
		}
	} elsif ($formkey_op =~ m{^(?:generate|regen)_formkey}) {
		# These ops can have "/foo" appended to them, in which case
		# the $formname parameter will be superceded by "foo".
		# This is for when e.g. the current op is creating a discussion
		# but we need to generate a new formkey for posting a comment
		# all in the same action.
		my $real_formname = $formname;
		if ($formkey_op =~ m{^(?:generate|regen)_formkey/(\w+)$}) {
			$real_formname = $1;
		}
		if (!$error_flag) {
			if (!$slashdb->createFormkey($real_formname)) {
				$error_flag = 1;
				$msg = formkeyError('cantinsert', $real_formname);
			}
		}
		if (!$error_flag && !$options->{no_hc}) {
			my $hc = getObject("Slash::HumanConf");
#print STDERR "formkeyHandler op '$formkey_op' hc '$hc'\n";
			if ($hc && !$hc->createFormkeyHC($real_formname)) {
				$error_flag = 1;
				$msg = formkeyError('cantinserthc', $real_formname);
			}
		}
	}
#print STDERR "formkeyHandler op '$formkey_op' formkey '$form->{formkey}' statehc '$user->{state}{hc}' error_flag '$error_flag' msg '$msg'\n";

	if ($msg) {
		if ($message_ref) {
			$$message_ref .= $msg;
		} else {
			print $msg;
		}
	}

	return $error_flag;
}

#========================================================================
sub submittedAlready {
	my($formkey, $formname, $err_message) = @_;
	my $slashdb = getCurrentDB();

	# find out if this form has been submitted already
	my($submitted_already, $submit_ts) = $slashdb->checkForm($formkey, $formname)
		or ($$err_message = Slash::getData('noformkey', '', ''), return);

	if ($submitted_already) {
		my $interval_string = $submit_ts
			? intervalString(time - $submit_ts)
			: ""; # never got submitted, don't know time
		$$err_message = Slash::getData('submitalready', {
			interval_string => $interval_string
		}, '');
	}
	return $submitted_already;
}

#========================================================================
sub checkFormPost {
	my($formname, $limit, $max, $id, $err_message) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = $slashdb->getCurrentUser();

	my $uid;

	if ($user->{uid} == $constants->{anonymous_coward_uid}) {
		$uid = $user->{ipid};
	} else {
		$uid = $user->{uid};
	}

	my $formkey_earliest = time() - $constants->{formkey_timeframe};
	# If formkey starts to act up, me doing the below
	# may be the cause
	my $formkey = getCurrentForm('formkey');

	my $last_submitted = $slashdb->getLastTs($id, $formname, 1);

	my $interval = time() - $last_submitted;

	if ($interval < $limit) {
		$$err_message = Slash::getData('speedlimit', {
			limit_string	=> intervalString($limit),
			interval_string	=> intervalString($interval)
		}, '');
		return;

	} else {
		if ($slashdb->checkTimesPosted($formname, $max, $id, $formkey_earliest)) {
			undef $formkey unless $formkey =~ /^\w{10}$/;

# wtf?  no method checkFormkey exists ...
# of course, checkFormPost is never even called ...
#			unless ($formkey && $slashdb->checkFormkey($formkey_earliest, $formname, $id, $formkey)) {
#				$slashdb->createAbuse("invalid form key", $formname, $ENV{QUERY_STRING});
#				$$err_message = Slash::getData('invalidformkey', '', '');
#				return;
#			}

			if (submittedAlready($formkey, $formname, $err_message)) {
				$slashdb->createAbuse("form already submitted", $formname, $ENV{QUERY_STRING});
				return;
			}

		} else {
			$slashdb->createAbuse("max form submissions $max reached", $formname, $ENV{QUERY_STRING});
			$$err_message = Slash::getData('maxposts', {
				max		=> $max,
				timeframe	=> intervalString($constants->{formkey_timeframe})
			}, '');
			return;
		}
	}
	return 1;
}

#========================================================================
sub filterOk {
	my($formname, $field, $content, $error_message) = @_;

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $filters = $slashdb->getContentFilters($formname, $field);

#	my $text_to_test = decode_entities(strip_nohtml($content));
	my $text_to_test = $content;
	my $report_prefix = "filterOk_report len1=" . length($text_to_test);
	$text_to_test = strip_nohtml($text_to_test);
	$report_prefix .= " len2=" . length($text_to_test);
	$text_to_test = decode_entities($text_to_test);
	$report_prefix .= " len3=" . length($text_to_test);

	$text_to_test =~ s/[\xA0]/ /g;
#	$text_to_test =~ s/<br>/\n/gi;
	$report_prefix .= " len4=" . length($text_to_test);
	study $text_to_test;

	# hash ref from db containing regex, modifier (gi,g,..),field to be
	# tested, ratio of field (this makes up the {x,} in the regex, minimum
	# match (hard minimum), minimum length (minimum length of that comment
	# has to be to be tested), err_message message displayed upon failure
	# to post if regex matches contents. make sure that we don't select new
	# filters without any regex data.
	for my $f (@$filters) {
		my $number_match	= '';
		my $regex		= $f->[2];
		my $modifier		= $f->[3] =~ /g/ ? 'g' : '';
		my $case		= $f->[3] =~ /i/ ? 'i' : '';
		my $field		= $f->[4];
		my $ratio		= $f->[5];
		my $minimum_match	= $f->[6];
		my $minimum_length	= $f->[7];
		my $err_message		= $f->[8];
		my $isTrollish		= 0;

		next if $minimum_length and length($text_to_test) < $minimum_length;

		if ($minimum_match) {
			$number_match = "{$minimum_match,}";
		} elsif ($ratio > 0) {
			my $num = int(length($text_to_test)*$ratio + 1);
			my $max = 2**15-1;
			# temporary fix 2008-05-23
			$num = $max if $num >= $max;
			$number_match = "{$num,}";
		} else {
			$number_match = "";
		}
		my $report .= "$report_prefix f=$f->[0]";
		$report .= " nm=$number_match uid=$user->{uid} ipid=$user->{ipid}";
		$report .= " karma=$user->{karma}" unless $user->{is_anon};
		$report .= " content=" . substr($content,0,200);
		$report =~ s/\s+/ /gs;

		# If the regex wants the number_match in a specific place or
		# places, put it there, otherwise just append it.
		if ($regex =~ s/__NM__/$number_match/g) {
			# OK, it's where it was wanted, nothing more required.
		} else {
			# If no __NM__ in the text, it gets appended.
			$regex .= $number_match;
		}

		$regex = $case eq 'i' ? qr/$regex/i : qr/$regex/;

		# Some of our regexes may have nested quantifiers, which can chew
		# CPU time exponentially.  To prevent a denial of service by posting
		# a comment with text designed to run away with the CPU, we limit
		# the amount of time we'll spend on any one filter for any one
		# comment.  Note that, in my testing, the only comments that sucked
		# CPU time were all ascii art... but to err on the side of caution,
		# text that gets interrupted is allowed to pass.
		my $matched = 0;
		eval {
			local $SIG{ALRM} = sub { die "timeout" };
			alarm 1;
			if ($modifier eq 'g') {
				$matched = 1 if $text_to_test =~ /$regex/g;
			} else {
				$matched = 1 if $text_to_test =~ /$regex/;
			}
			alarm 0;
		};
		if ($@ and $@ =~ /timeout/) {
			print STDERR "$report TIMEOUT\n";
		} elsif ($matched) {
			$$error_message = $err_message;
			$slashdb->createAbuse("content filter", $formname, $text_to_test);
			print STDERR "$report\n";
			return 0;
		}
	}
	return 1;
}

#========================================================================
sub compressOk {
	# leave it here, it causes problems if use'd in the
	# apache startup phase
	require Compress::Zlib;
	my($formname, $field, $content, $wsfactor) = @_;
	$wsfactor ||= 1;

	# If no content (or I suppose the single char '0') is passed in,
	# just report that it passes the test.  Hopefully the caller is
	# performing other checks to make sure that boundary condition
	# is addressed.
	return 1 if !$content;

	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();

	my $uid;
	if ($user->{uid} == $constants->{anonymous_coward_uid}) {
		$uid = $user->{ipid};
	} else {
		$uid = $user->{uid};
	}

	# These could be tweaked.  $slice_size could be roughly 300-2000;
	# the $x_space vars could go up or down by a factor of roughly 2.
	# "wsfactor" is the whitespace factor;  normal is 1.0, but the
	# larger the value the more difficult to accept a comment with lots
	# of whitespace.  Values between 0.2 and 5 probably make sense.
	my $slice_size = $constants->{comment_compress_slice} || 500;
	my $nbsp_space = " " x (1 + int(1 * $wsfactor));
	my $breaktag_space = " " x (1 + int(1 * $wsfactor));
	my $spacerun_min = 1 + int(16 / $wsfactor);
	my $spacerun_exp = 1 + 0.1 * $wsfactor;

	my $orig_length = length($content);
	my $slice_remainder = $orig_length % $slice_size;
	my $n_slices = int($orig_length/$slice_size + 1/3); # round slightly up
	if ($n_slices == 0) {
		$slice_size = $orig_length;
	} else {
		$slice_size = int($orig_length/$n_slices) + 1;
	}

	my $limits = {
		0.8  => [ 10, 19],		# was 1.3
		0.65 => [ 20, 29],		# was 1.1
		0.5  => [ 30, 44],		# was 0.8
		0.4  => [ 45, 99],		# was 0.5
		0.35 => [100,199],		# was 0.4
		0.3  => [200,299],
		0.2  => [300,2**31-1],
	};

	while ($content) {
		# Slice off a hunk from the front and check it.
		my $content_slice = substr($content, 0, $slice_size);
		substr($content, 0, $slice_size) = "";

		# too short to bother?
		my $length = length($content_slice);
		next if $length < 10;

		# Runs of whitespace get increased in size for purposes of the
		# compression check, since they are commonly used in ascii art
		# (runs of anything will be compressed more).
		$content_slice =~ s{(\s{$spacerun_min,})}
			{" " x (length($1) ** $spacerun_exp)}ge;
		# Whitespace _tags_ also get converted to runs of spaces.
		$content_slice =~ s/<\/?(BR|P|DIV)>/$breaktag_space/gi;
		# Whitespace entities get similar special treatment.
		$content_slice =~ s/\&(nbsp|#160|#xa0);/$nbsp_space/gi;
		# Other entities just get decoded before the compress check.
		$content_slice = decode_entities($content_slice);

		# The length we compare against for ratios is the length of the
		# modified slice of the text.
		$length = length($content_slice);
		next if $length < 10;

		# compress doesn't like wide characters.  this could in theory
		# make it easier to run into a filter, with too many '_'
		# characters being in a comment, but no one should be using
		# that many wide characters in the standard English
		# alphabet.  we can adjust filters if necessary. -- pudge
		$content_slice =~ s/(.)/ord($1) > 2**8-1 ? '_' : $1/ge;

		for (sort { $a <=> $b } keys %$limits) {
			next unless $length >= $limits->{$_}->[0]
				and $length <= $limits->{$_}->[1];

			# OK, we have the right numbers for the size of this slice.
			# Compress it and check its size.
			my $comlen = length(Compress::Zlib::compress($content_slice));
			if (($comlen / $length) <= ($_ * 1.3)) {
				# It either compresses too well, or it's close;
				# drop a line to the debug log.
				my $report = "compressOk_report ss=$slice_size leno=$orig_length len1=$length";
				$report .= " comlen=$comlen field=$field";
				$report .= sprintf(" ratio=%0.3f max=$_", $comlen/$length);
				$report .= " uid=$user->{uid}";
				$report .= " karma=$user->{karma}" if !$user->{is_anon};
				$report .= " ipid=$user->{ipid}";
				$report .= " content=".substr($content, 0, 200);
				$report =~ s/\s+/ /gs;
				print STDERR "$report\n";
			}
			if (($comlen / $length) <= $_) {
				$slashdb->createAbuse("content compress", $formname, $content);
				return 0;
			}
		}
	}

	# Every slice of the comment text passed the test, so it's OK.
	return 1;
}

#========================================================================

=head2 allowExpiry()

Returns whether the system allows user expirations or not.

=over 4

=item Return value

Boolean value. True if users are to be expired, false if not.

The following variables can control this behavior:
	min_expiry_days
	max_expiry_days
	min_expiry_comm
	max_expiry_comm

	do_expiry

=back

=cut

sub allowExpiry {
	my $constants = getCurrentStatic();

	# We only perform the check if any of the following are turned on.
	return ($constants->{min_expiry_days} > 0 ||
		$constants->{max_expiry_days} > 0 ||
		$constants->{min_expiry_comm} > 0 ||
		$constants->{max_expiry_comm} > 0
	) && $constants->{do_expiry};
}

#========================================================================

=head2 setUserExpiry($uid, $val)

Set/Clears the expired status on the given UID based on $val. If $val
is non-zero, then expiration will be performed on the user, this
include:
	- Generating a registration ID for the user so that they can re-register.
	- Marking all forms in vars.[expire_forms] as read-only.
	- Clearing the registration flag.
	- Sending the registration email which notifies user of expiration.

If $val is non-zero, then the above operations are "cleared" by
performing the following:

	- Clearing the registration ID associated with the user.
	  (it's not the job of this routine to perform checks on reg-id)
	- Unmarking all forms marked read-only (note: this is NOT a deletion!)
	- Setting the registration flag.

=over 4

=item Return value

None.

=back

=cut

sub setUserExpired {
	my($uid, $val) = @_;

	my $user = getCurrentUser($uid);
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	# Apply the appropriate readonly flags.
	for (split /,\s+/, $constants->{expire_forms}) {
		$slashdb->setReadOnly($_, $uid, $val, 0, 'expired');
	}

	if ($val) {
		# Determine regid. We want to strive for as much randomness as we
		# can without getting overly complex. Let's just create a string
		# that should have a reasonable degree of uniqueness by user.
		#
		# Now, how likely is it that this will result in a collision?
		# Note that we obscure with an MD5 hex has which is safer in URLs
		# than base64 hashes.
		my $regid = md5_hex(
			(sprintf "%s%s%d", time, $user->{nickname}, int(rand 256))
		);

		# We now unregister the user, but we need to keep the ID for later.
		# Consider removal of the 'registered' flag. This state can simply
		# be determined by the presence of a non-zero length value in
		# 'reg_id'. If 'reg_id' doesn't exist, that is considered to be
		# a zero-length value.
		$slashdb->setUser($uid, {
			'registered'    => '0',
			'reg_id'        => $regid,
		});

		my $reg_msg = slashDisplay('rereg_mail', {
			# This should probably be renamed to prevent confusion.
			# But there is no real need for the CURRENT user's value
			# in this template, just the user we are expiring.
			reg_id		=> $regid,
			useradmin	=> $constants->{reg_useradmin} ||
				$constants->{adminmail},
		}, {
			Return  => 1,
			Nocomm  => 1,
			Page    => 'messages',
		});

		my $reg_subj = Slash::getData('rereg_email_subject', '', '');

		doEmail($uid, $reg_subj, $reg_msg, MSG_CODE_REGISTRATION);
	} else {
		# We only need to clear these.
		$slashdb->setUser($uid, {
			'registered'	=> '1',
			'reg_id'	=> '',
		});
	}
}

####################################################
# Basically do the discussion logic bit to find the
# state of the discussion (takes a discussion and 
# returns the state -Brian
sub isDiscussionOpen {
	my($discussion) = @_;
	return 'archived' 
		if $discussion->{commentstatus} eq 'disabled';
	return $discussion->{type}
		if $discussion->{type} eq 'archived';
	return $discussion->{type}
		if $discussion->{commentstatus} eq 'enabled';
	return $discussion->{type}
		if $discussion->{uid} eq getCurrentUser('uid');

	# Now for the more complicated possibilities -Brian
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $people = $slashdb->getUser($discussion->{uid}, 'people');
	if ($discussion->{commentstatus} eq 'friends_only'
		|| $discussion->{commentstatus} eq 'friends_fof_only') {
		my $orig = $discussion->{type};
		$discussion->{type} = 'archived';
		if ($people) {
			$discussion->{type} = $orig if ($people->{FRIEND()}{$user->{uid}}
				|| (
				$discussion->{commentstatus} eq 'friends_fof_only'
					&&
				$people->{FOF()}{$user->{uid}}
					&&
				!$people->{FOE()}{$user->{uid}}
				)
			);
		}
	} elsif ($discussion->{commentstatus} eq 'no_foe' || $discussion->{commentstatus} eq 'no_foe_eof') {
		# there's no sense in allowing anonymous
		# users if we diallow foes, else foes
		# can post anonymously
		if ($user->{is_anon}) {
			$discussion->{type} = 'archived';
		} elsif ($people) {
			$discussion->{type} = 'archived' if ($people->{FOE()}{$user->{uid}}
				|| (
					$discussion->{commentstatus} eq 'no_foe_eof'
						&&
					!$people->{FRIEND()}{$user->{uid}}
						&&
					$people->{EOF()}{$user->{uid}}
				)
			);
		}
	} elsif ($discussion->{commentstatus} eq 'logged_in') {
		# user just has to be logged in, but A.C. posting still allowed
		if ($user->{is_anon}) {
			$discussion->{type} = 'archived';
		}
	}

	$discussion->{user_nopost} = 1 if $discussion->{type} eq 'archived';

	return $discussion->{type};
}


1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).
