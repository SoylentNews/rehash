# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Messages;

=head1 NAME

Slash::Messages - Send messages for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	my $messages = getObject('Slash::Messages');
	my $msg_id = $messages->create($uid, $message_type, $message);

	# ...
	my $msg = $messages->get($msg_id);
	$messages->send($msg);
	$messages->delete($msg_id);

	# ...
	$messages->process($msg_id);


=head1 DESCRIPTION

More to come.

=head1 OBJECT METHODS

=cut

use strict;
use base qw(Slash::Messages::DB::MySQL);
use vars qw($VERSION);
use Email::Valid;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants ':messages';
use Slash::Display;
use Slash::Utility;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


#========================================================================

=head2 create(TO_ID, TYPE, MESSAGE [, FROM_ID, ALTTO])

Will drop a serialized message into message_drop.

=over 4

=item Parameters

=over 4

=item TO_ID

The UID of the user the message is sent to.  Must match a valid
uid in the users table.

=item TYPE

The message type.  Preferably a number, but will also handle strings
(but those are subject to change by a site admin!).  It is best to
stick with a number.

=item MESSAGE

This is either the exact text to send, or it is a hashref
containing the data to send.  To override the default
"subject" of the message, pass it in as the "subject"
key.  Pass the name of the template in as the "template_name"
key.  If "subject" is a template, then pass it as a hashref,
with "template_name" as one of the keys.

=item FROM_ID

Either the UID of the user sending the message, or 0 to denote
a system message (0 is default).

=item ALTTO

This is an alternate "TO" address (e.g., to send a message from
a user of the system to a user outside the system).

=back

=item Return value

The created message's "id" in the message_drop table.

=item Dependencies

Whatever templates are passed in.

=back

=cut

sub create {
	my($self, $uid, $type, $data, $fid, $altto) = @_;
	my $message;

	# must not contain non-numeric
	if (!defined($fid) || $fid =~ /\D/) {
		$fid = 0;
	}

	my $origtype = $type;
	(my($code), $type) = $self->getDescription('messagecodes', $type);
	unless (defined $code) {
		messagedLog(getData("type not found", { type => $origtype }, "messages"));
		return 0;
	}

	if (!$altto) {
		# check for $uid existence
		my $slashdb = getCurrentDB();
		unless ($slashdb->getUser($uid)) {
			messagedLog(getData("user not found", { uid => $uid }, "messages"));
			return 0;
		}
	} else {
		if (!defined($uid) || $uid =~ /\D/) {
			$uid = 0;
		}
	}

	if (!ref $data) {
		$message = $data;
	} elsif (ref $data eq 'HASH') {
		# copy parent data structure so it is not modified,
		# so it is left alone on return back to caller
		$data = { %$data };
		unless ($data->{template_name}) {
			messagedLog(getData("no template", 0, "messages"));
			return 0;
		}

		my $user = getCurrentUser();
		$data->{_NAME}    = delete($data->{template_name});
		$data->{_PAGE}    = delete($data->{template_page})
			|| $user->{currentPage};
		$data->{_SECTION} = delete($data->{template_section})
			|| $user->{currentSection};

		# set subject
		if (exists $data->{subject} && ref($data->{subject}) eq 'HASH') {
			# copy parent data structure so it is not modified,
			# so it is left alone on return back to caller
			$data->{subject} = { %{$data->{subject}} };
			unless ($data->{subject}{template_name}) {
				messagedLog(getData("no template subject", 0, "messages"));
				return 0;
			}

			$data->{subject}{_NAME}    = delete($data->{subject}{template_name});
			$data->{subject}{_PAGE}    = delete($data->{subject}{template_page})
				|| $data->{_PAGE}    || $user->{currentPage};
			$data->{subject}{_SECTION} = delete($data->{subject}{template_section})
				|| $data->{_SECTION} || $user->{currentSection};
		}

		$data->{_templates}{email}{content}	||= 'msg_email';
		$data->{_templates}{email}{subject}	||= 'msg_email_subj';
		$data->{_templates}{web}{subject}	||= 'msg_web_subj';
		$data->{_templates}{content}		||= '';
		$data->{_templates}{subject}		||= '';

		$message = $data;

	} else {
		messagedLog(getData("wrong type", { type => ref($data) }, "messages"));
		return 0;
	}

	my($msg_id) = $self->_create($uid, $code, $message, $fid, $altto);
	return $msg_id;
}

#========================================================================

=head2 create_web(MESSAGE)

Create a message record in message_web.

=over 4

=item Parameters

=over 4

=item MESSAGE

A rendered message hashref.

=back

=item Return value

The message ID.

=back

=cut

sub create_web {
	my($self, $msg) = @_;

	my($msg_id) = $self->_create_web(
		$msg->{user}{uid},
		$msg->{code},
		$msg->{message},
		(ref($msg->{fuser}) ? $msg->{fuser}{uid} : $msg->{fuser}),
		$msg->{id},
		$msg->{subject},
		$msg->{date}
	);
	return $msg_id;
}

#========================================================================

=head2 process(MESSAGES)

Process a list of messages, sending them and deleting them when sent.

=over 4

=item Parameters

=over 4

=item MESSAGES

A list of messages.  Each message may be a rendered message hashref
or a message ID.

=back

=item Return value

An array of 

=item Side effects


=item Dependencies

=back

=cut

# takes message refs or message IDs or a combination of both
sub process {
	my($self, @msgs) = @_;

	my(@success);
	for my $msg (@msgs) {
		# if $msg is ref, assume we have the message already
		$msg = $self->get($msg) unless ref($msg);
		if ($self->send($msg)) {
			push @success, $msg->{id}
				if $self->delete($msg->{id});
		}
	}
	return @success;
}

#========================================================================

=head2 checkMessageCodes(CODE, UIDS)

Returns a list of UIDs from UIDS that are set to recieve messages for CODE.

=over 4

=item Parameters

=over 4

=item CODE

Message code to test.

=item UIDS

List of UIDs to test.

=back

=item Return value

List of UIDs from UIDS that are set to receive messages for CODE.

=back

=cut

sub checkMessageCodes {
	my($self, $code, $uids) = @_;
	my @newuids;
	for my $uid (@$uids) {
		my $prefs = $self->getPrefs($uid);
		push @newuids, $uid
			if defined $prefs->{$code} && $prefs->{$code} >= 0;
	}
	return \@newuids;
}

# must return an array ref
sub getMessageUsers {
	my($self, $code) = @_;
	my $coderef = $self->getMessageCode($code) or return [];
	my $users = $self->_getMessageUsers($code, $coderef->{seclev});
	return $users || [];
}


sub getMode {
	my($self, $msg) = @_;
	my $code = $msg->{code};
	my $mode = $msg->{user}{prefs}{$code};

	my $coderef = $self->getMessageCode($code) or return MSG_MODE_NOCODE;

	# user not allowed to receive this message type
	return MSG_MODE_NOCODE if $msg->{user}{seclev} < $coderef->{seclev};

	# user has no delivery mode set
	return MSG_MODE_NONE if	$mode == MSG_MODE_NONE
		|| !defined($mode) || $mode eq '' || $mode =~ /\D/;

	# if sending to someone outside the system, must be email
	# delivery mode (for now) -- CHANGE FOR JABBER
	$mode = MSG_MODE_EMAIL if $msg->{altto};

	# Can only get mail sent if registered is set
	if ($mode == MSG_MODE_EMAIL && !$msg->{user}{registered}) {
		$mode = MSG_MODE_WEB;
	}

	# check if mode is allowed for specific type; default to email
	if (length($coderef->{modes}) && !grep /\b$mode\b/, $coderef->{modes}) {
		if (!$msg->{user}{registered}) {
			$mode = MSG_MODE_NONE;
		} else {
			$mode = MSG_MODE_EMAIL;
		}
	}

	return $msg->{mode} = $mode;
}

sub getNewsletterUsers {
	my($self) = @_;
	return $self->_getMailingUsers(0);
}

sub getHeadlineUsers {
	my($self) = @_;
	return $self->_getMailingUsers(1);
}

sub getNewsletterUsersCount {
	my($self) = @_;
	return scalar @{$self->_getMailingUsersRaw(0)};
}

sub getHeadlineUsersCount {
	my($self) = @_;
	return scalar @{$self->_getMailingUsersRaw(1)};
}

# takes message ref or message ID
sub send {
	my($self, $msg) = @_;

	my $constants = getCurrentStatic();

	# if $msg is ref, assume we have the message already
	$msg = $self->get($msg) unless ref($msg);

	my $mode = $msg->{mode};

	# should NONE, NOCODE, UNKNOWN delete msg? -- pudge
	if ($mode == MSG_MODE_NONE) {
		messagedLog(getData("no delivery mode", {
			uid	=> $msg->{user}{uid}
		}, "messages"));
		return 0;

	} elsif ($mode == MSG_MODE_NOCODE) {
		messagedLog(getData("no message code", {
			code	=> $msg->{code},
			uid	=> $msg->{user}{uid}
		}, "messages"));
		return 0;

	} elsif ($mode == MSG_MODE_EMAIL) {
		my($addr, $content, $subject, $contemp, $subtemp);

		# print errors to slashd.log under slashd only if high level
		# of verbosity -- pudge
		my $log_error = defined &main::verbosity ? main::verbosity() >= 3 : 1;

		unless ($constants->{send_mail}) {
			messagedLog(getData("send_mail false", 0, "messages"));
			return 0;
		}

		$addr    = $msg->{altto} || $msg->{user}{realemail};
		unless (Email::Valid->rfc822($addr)) {
			messagedLog(getData("send mail error", {
				addr	=> $addr,
				uid	=> $msg->{user}{uid},
				error	=> "Invalid address"
			}, "messages")) if $log_error;
			return 0;
		}

		$contemp = $msg->{_templates}{email}{content}
			|| $msg->{_templates}{content};
		$subtemp = $msg->{_templates}{email}{subject}
			|| $msg->{_templates}{subject};
		$content = $contemp ? $self->callTemplate($contemp, $msg) : $msg->{message};
		$subject = $subtemp ? $self->callTemplate($subtemp, $msg) : $msg->{subject};

		if (sendEmail($addr, $subject, $content, $msg->{priority})) {
			$self->log($msg, MSG_MODE_EMAIL);
			return 1;
		} else {
			messagedLog(getData("send mail error", {
				addr	=> $addr,
				uid	=> $msg->{user}{uid},
				error	=> $Mail::Sendmail::error
			}, "messages")) if $log_error;
			return 0;
		}

	} elsif ($mode == MSG_MODE_WEB) {
		if ($self->create_web($msg)) {
			$self->log($msg, MSG_MODE_WEB);
			return 1;
		} else {
			return 0;
		}

	} else {
		messagedLog(getData("unknown mode", {
			mode	=> $mode,
			uid	=> $msg->{user}{uid},
		}, "messages"));
		return 0;
	}

}

sub getWebCount {
	my($self, $uid) = @_;
	$self->_get_web_count_by_uid($uid);
}

# this method will only send email, and it assumes that the caller
# already checked (if appropriate) whether or not the user is
# allowed to get email sent to them, and whether or not they are
# allowed to get this particular email type
sub quicksend {
	my($self, $tuser, $subj, $message, $code, $pr) = @_;
	my $slashdb = getCurrentDB();

	return unless $tuser;
	($code, my($type)) = $self->getDescription('messagecodes', $code);
	$code = -1 unless defined $code;

	my %msg = (
		id		=> 0,
		fuser		=> 0,
		subject		=> $subj,
		message		=> $message,
		code		=> $code,
		type		=> $type,
		date		=> time(),
		mode		=> MSG_MODE_EMAIL,
		priority	=> $pr,
	);

	# allow for altto
	if ($tuser =~ /\D/) {
		$msg{user}{uid}	= 0;
		$msg{altto}	= $tuser;
	} else {
		$msg{user}	= $slashdb->getUser($tuser);
		$msg{altto}	= '';
	}

	$self->send(\%msg);
}

sub bulksend {
	my($self, $addrs, $subj, $message, $code, $uid) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	unless ($constants->{send_mail}) {
		messagedLog(getData("send_mail false", 0, "messages"));
		return 0;
	}

	($code, my($type)) = $self->getDescription('messagecodes', $code);
	$code = -1 unless defined $code;

	$uid ||= 0;
	my $msg = {
		id		=> 0,
		fuser		=> 0,
		altto		=> '',
		user		=> $uid,
		subject		=> $subj,
		message		=> $message,
		code		=> $code,
		type		=> $type,
		date		=> time(),
		mode		=> MSG_MODE_EMAIL,
	};

	my $content = $self->callTemplate('msg_email', $msg);
	my $subject = $self->callTemplate('msg_email_subj', $msg);

	if (bulkEmail($addrs, $subject, $content)) {
		$self->log($msg, MSG_MODE_EMAIL);
		return 1;
	} else {
		messagedLog(getData("send mail error", {
			addr	=> "[bulk]",
			uid	=> $uid,
			error	=> "unknown error",
		}, "messages"));
		return 0;
	}
}

sub getWeb {
	my($self, $msg_id) = @_;

	my $msg = $self->_get_web($msg_id) or return 0;
	$self->render($msg, 1);
	return $msg;
}

sub getWebByUID {
	my($self, $uid) = @_;
	$uid ||= $ENV{SLASH_USER};

	my $msgs = $self->_get_web_by_uid($uid) or return 0;
	$self->render($_, 1) for @$msgs;
	return $msgs;
}

#========================================================================

=head2 get(ID)

Get message with ID from messages queue.

=over 4

=item Parameters

=over 4

=item ID

The message ID of the message to get.

=back

=item Return value

A hashref containing the rendered message.

=back

=cut

sub get {
	my($self, $msg_id) = @_;

	my $msg = $self->_get($msg_id) or return 0;
	$self->render($msg);
	return $msg;
}

#========================================================================

=head2 gets([COUNT])

Get the next COUNT messages from the messages queue.

=over 4

=item Parameters

=over 4

=item COUNT

A number of messages to fetch.  Will fetch the oldest messages.
If COUNT is false, will fetch all messages.

=back

=item Return value

An arrayref of hashrefs of rendered messages.

=back

=cut

sub gets {
	my($self, $count) = @_;

	my $msgs = $self->_gets($count) or return 0;
	$self->render($_) for @$msgs;
	return $msgs;
}

#========================================================================

=head2 delete(IDS)

Delete the messages of the given IDS from the messages queue.

=over 4

=item Parameters

=over 4

=item IDS

A list of message IDS to delete.

=back

=item Return value

Number of messages deleted.

=item Side effects

Maybe we should log the deletions somewhere?  Creation date,
uid, type, and deletion date?

=item Dependencies

=back

=cut

sub delete {
	my($self, @ids) = @_;

	my $count;
	for (@ids) {
		$count += $self->_delete($_);
	}
	return $count;
}

#========================================================================

=head2 render(MESSAGE [, NOTEMPLATE])

Given message data from the database, renders the message by filling
in the user's information from the database, getting the description
for the message code, and rendering the templates as appropriate.

This method should always be called after getting the data from the
database, and before using the data.  It is called automatically
by the get* methods.

=over 4

=item Parameters

=over 4

=item MESSAGE

The hashref of data from the database (see the get* methods).

=item NOTEMPLATE

Boolean for whether or not the templates should be processed.  In
the get() and gets() methods, this boolean is false, because the raw
unrendered template data is stored in those messages.  But for the
getWeb() and getWebByUID() methods, the templates have already been
rendered and stored in the messages_web table, so the templates
should not be processed.

=back

=item Return value

The hashref containing the rendered message data.

=back

=cut


sub render {
	my($self, $msg, $notemplate) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	$msg->{user}		= $msg->{user}  ? $slashdb->getUser($msg->{user})  : { uid => 0 };
	$msg->{user}{prefs}	= $self->getPrefs($msg->{user}{uid} || $constants->{anonymous_coward_uid});
	$msg->{fuser}		= $msg->{fuser} ? $slashdb->getUser($msg->{fuser}) : 0;
	$msg->{type}		= $self->getDescription('messagecodes', $msg->{code});
	setUserDate($msg->{user}) if $msg->{user}{uid};

	# sets $msg->{mode} too
	my $mode = $self->getMode($msg);

	unless ($notemplate) {
		$msg->{_templates} = $msg->{message}{_templates};

		# set subject
		if (ref($msg->{message}) ne 'HASH' || !exists $msg->{message}{subject}) {
			my $subtemp_e = $msg->{_templates}{email}{subject}
				|| $msg->{_templates}{subject};
			my $subtemp_w = $msg->{_templates}{web}{subject}
				|| $msg->{_templates}{subject};
			my $name = $mode == MSG_MODE_EMAIL ? $subtemp_e :
				   $mode == MSG_MODE_WEB   ? $subtemp_w : '';
			$msg->{subject} = $self->callTemplate($name, $msg) if $name;
		} else {
			my $subject = $msg->{message}{subject};
			if (ref($msg->{message}{subject}) eq 'HASH') {
				$msg->{subject} = $self->callTemplate({ %{$msg->{message}}, %$subject }, $msg);
			} else {
				$msg->{subject} = $subject;
			}
		}

		$msg->{message} = $self->callTemplate($msg->{message}, $msg);
	}

	return $msg;
}

#========================================================================

=head2 callTemplate(DATA, MESSAGE)

A wrapper for calling templates in Slash::Messages.  It tries to figure
out the right page/section to call the template in, etc.  It sets the
Nocomm parameter in its call to slashDisplay().

=over 4

=item Parameters

=over 4

=item DATA

This can either be a template name, or a hashref of template data.
If a hashref, the _NAME parameter is the template name.  The
_PAGE and _SECTION parameters may also be set.  These will all be
set appropriately by the create() method.  The rest of
the key/value pairs will be passed to the template.

=item MESSAGE

The message hashref.  This will be assigned to the "msg" template
variable, e.g., so you can call "msg.mode" and "msg.id" in the
template.

=back

=item Return value

The rendered template.

=back

=cut


sub callTemplate {
	my($self, $data, $msg) = @_;
	my $name;

	if (ref($data) eq 'HASH' && exists $data->{_NAME}) {
		$name = delete($data->{_NAME});
	} elsif ($data && !ref($data)) {
		$name = $data;
		$data = {};
	} else {
		return 0;
	}

	my $opt  = {
		Return	=> 1,
		Nocomm	=> 1,
		Page	=> 'messages',
		Section => 'NONE',
	};

	# set Page and Section as from the caller
	$opt->{Page}    = delete($data->{_PAGE})    if exists $data->{_PAGE};
	$opt->{Section} = delete($data->{_SECTION}) if exists $data->{_SECTION};

	my $new = slashDisplay($name, { %$data, msg => $msg }, $opt);
	return $new;
}

#========================================================================

=head2 getDescription(CODETYPE, KEY)

Given a codetype, will fetch a description if KEY is a code,
and code if KEY is a description.  KEY is determined to be a code
if it is an integer.

=over 4

=item Parameters

=over 4

=item CODETYPE

A type of code, such as "deliverymodes" or "messagecodes".

=item KEY

A code or description.

=back

=item Return value

This is a little bit tricky.

In scalar context, if KEY is code, return description;
if KEY is description, return code.  In list context,
always return a list of (code, description).

=back

=cut

sub getDescription {
	my($self, $codetype, $key) = @_;

	my $codes = $self->getDescriptions($codetype);

	if ($key =~ /^\d+$/) {
		unless (exists $codes->{$key}) {
			return;
		}
		return wantarray ? ($key, $codes->{$key}) : $codes->{$key};
	} else {
		my $rcodes = { map { ($codes->{$_}, $_) } keys %$codes };
		unless (exists $rcodes->{$key}) {
			return;
		}
		return wantarray ? ($rcodes->{$key}, $key) : $rcodes->{$key};
	}
}

#========================================================================

=head2 messagedLog(ERROR)

Will dispatch error message to main::messagedLog() (if exists)
or errorLog().  main::messagedLog() will normally exist only when
the message_delivery task is running under slashd.

=over 4

=item Parameters

=over 4

=item ERROR

Error message to log.

=back

=item Side effects

goto() is used, so this function will not show up in a stack trace.

=back

=cut

# dispatch to proper logging function
sub messagedLog {
	goto &main::messagedLog if defined &main::messagedLog;
	goto &errorLog;
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
