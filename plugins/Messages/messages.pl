#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# this program does some really cool stuff.
# so i document it here.  yay for me!

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web :messages);
use Slash::Display;
use Slash::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $messages  = getObject('Slash::Messages');
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	# require POST and logged-in user for these ops
	my $user_ok   = $user->{state}{post} && !$user->{is_anon};

	# possible value of "op" parameter in form
	my %ops = (
		display_prefs	=> [ !$user->{is_anon},	\&display_prefs		],
		save_prefs	=> [ $user_ok,		\&save_prefs		],
		list_messages	=> [ !$user->{is_anon},	\&list_messages		],
		list		=> [ !$user->{is_anon},	\&list_messages		],
		display_message	=> [ !$user->{is_anon},	\&display_message	],
		display		=> [ !$user->{is_anon},	\&display_message	],
		delete_message	=> [ $user_ok,		\&delete_message	],
		deletemsgs	=> [ $user_ok,		\&delete_messages	],

# 		send_message	=> [ $user_ok,		\&send_message		],
# 		edit_message	=> [ !$user->{is_anon},	\&edit_message		],

		# ????
		default		=> [ 1,			\&list_messages		]
	);

	# prepare op to proper value if bad value given
	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	# dispatch of op
	$ops{$op}[FUNCTION]->($messages, $constants, $user, $form);

	# writeLog('SOME DATA');	# if appropriate
}

sub edit_message {
	my($messages, $constants, $user, $form, $error_message) = @_;

	my $template = <<EOT;
[% IF preview %]
	[% PROCESS titlebar width="100%" title="Preview Message" %]
	[% preview %]
	<P>
[% END %]
	[% PROCESS titlebar width="100%" title="Send Message" %]

<!-- error message -->
[% IF error_message %][% error_message %][% END %]
<!-- end error message -->

<FORM ACTION="[% constants.rootdir %]/messages.pl" METHOD="POST">
	<INPUT TYPE="HIDDEN" NAME="op" VALUE="send_message">
[% IF form.formkey %]
	<INPUT TYPE="HIDDEN" NAME="formkey" VALUE="[% form.formkey %]">
[% END %]

	<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="1">
	<TR><TD ALIGN="RIGHT">User: </TD>
		<TD><INPUT TYPE="text" NAME="to_user" VALUE="[% form.to_user | strip_attribute %]" SIZE=50 MAXLENGTH=50></TD>
	</TR>
	<TR><TD ALIGN="RIGHT">Subject: </TD>
		<TD><INPUT TYPE="text" NAME="postersubj" VALUE="[% form.postersubj | strip_attribute %]" SIZE=50 MAXLENGTH=50></TD>
	</TR>
	<TR>
		<TD ALIGN="RIGHT" VALIGN="TOP">Comment</TD>
		<TD><TEXTAREA WRAP="VIRTUAL" NAME="postercomment" ROWS="[% user.textarea_rows || constants.textarea_rows %]" COLS="[% user.textarea_cols || constants.textarea_cols %]">[% form.postercomment | strip_literal %]</TEXTAREA>
		<BR>(Use the Preview Button! Check those URLs!
		Don't forget the http://!)
	</TD></TR>

	<TR><TD> </TD><TD>

		<INPUT TYPE="SUBMIT" NAME="which" VALUE="Submit">
		<INPUT TYPE="SUBMIT" NAME="which" VALUE="Preview">
	</TD></TR><TR>
		<TD VALIGN="TOP" ALIGN="RIGHT">Allowed HTML: </TD><TD><FONT SIZE="1">
			&lt;[% constants.approvedtags.join("&gt;			&lt;") %]&gt;
		</FONT>
	</TD></TR>
</TABLE>

</FORM>

<B>Important Stuff:</B>
	<LI>Please try to keep posts on topic.
	<LI>Try to reply to other people comments instead of starting new threads.
	<LI>Read other people's messages before posting your own to avoid simply duplicating
		what has already been said.
	<LI>Use a clear subject that describes what your message is about.
	<LI>Offtopic, Inflammatory, Inappropriate, Illegal, or Offensive comments might be
		moderated. (You can read everything, even moderated posts, by adjusting your
		threshold on the User Preferences Page)

<P><FONT SIZE="2">Problems regarding accounts or comment posting should be sent to
	<A HREF="mailto:[% constants.adminmail %]">[% constants.siteadmin_name %]</A>.</FONT>


EOT

	header(getData('header'));
	# print edit screen
	slashDisplay(\$template, {error_message => $error_message});
	footer();
}

sub send_message {
	my($messages, $constants, $user, $form) = @_;
	my $slashdb = getCurrentDB();


	# edit_message if errors
	if ($form->{which} eq 'Preview') {
		edit_message(@_);
	}

	# check for user
	my $to_uid = $slashdb->getUserUID($form->{to_user});
	if (!$to_uid) {
		edit_message(@_, "UID for $form->{to_user} not found");
	}
	my $to_user = $slashdb->getUser($to_uid);
	if (!$to_user) {  # should never happen
		edit_message(@_, "$form->{to_user} ($to_uid) not found");
	}

	# check for user availability
	my $users = $messages->checkMessageCodes(MSG_CODE_INTERUSER, [$to_uid]);
	my $ium = $user->{messages_interuser_receive};
	if ($users->[0] != $to_uid || !$ium) {
		edit_message(@_, "$form->{to_user} ($to_uid) is not accepting interuser messages");
	}

	if ($ium != MSG_IUM_ANYONE) {
		my $zoo = getObject('Slash::Zoo');
		if ($ium == MSG_IUM_FRIENDS && !$zoo->isFriend($user->{uid}, $to_uid)) {
			edit_message(@_, "$form->{to_user} ($to_uid) only accepts messages from friends");
		} elsif ($ium == MSG_IUM_NOFOES && $zoo->isFoe($user->{uid}, $to_uid)) {
			edit_message(@_, "$form->{to_user} ($to_uid) does not accept messages from foes");
		}
	}

	$messages->create($to_uid, MSG_CODE_INTERUSER, {
		template_name	=> 'interuser',
		subject		=> {
			template_name	=> 'interuser_subj',
			subject		=> $form->{postersubj},
		},
		comment		=> {
			subject		=> $form->{postersubj},
			comment		=> $form->{postercomment},
		},
	}, $user->{uid});


	header();
	footer();	

	# print success screen
}



sub display_prefs {
	my($messages, $constants, $user, $form, $note) = @_;
	my $slashdb = getCurrentDB();

	my $deliverymodes = $messages->getDescriptions('deliverymodes');
	my $messagecodes  = $messages->getDescriptions('messagecodes');

	my $uid = $user->{uid};
	if ($user->{seclev} >= 1000 && $form->{uid}) {
		$uid = $form->{uid};
	}

	my $prefs = $messages->getPrefs($uid);
	my $userm = $slashdb->getUser($uid); # so we can modify a different user other than ourself

	header(getData('header'));
	print createMenu('users', {
		style =>	'tabbed',
		justify =>	'right',
		color =>	'colored',
		tab_selected =>	'preferences',
	});
	slashDisplay('prefs_titlebar', {
		nickname => $user->{nickname},
		uid => $user->{uid},
		tab_selected => 'messages'
	});
	print createMenu('messages');
	slashDisplay('display_prefs', {
		userm		=> $userm,
		prefs		=> $prefs,
		note		=> $note,
		messagecodes	=> $messagecodes,
		deliverymodes	=> $deliverymodes,
	});
	footer();
}

sub save_prefs {
	my($messages, $constants, $user, $form) = @_;
	my $slashdb = getCurrentDB();

	my(%params, %prefs);
	my $uid = $user->{uid};
	if ($user->{seclev} >= 1000 && $form->{uid}) {
		$uid = $form->{uid};
	}

	my $messagecodes = $messages->getDescriptions('messagecodes');
	for my $code (keys %$messagecodes) {
		my $coderef = $messages->getMessageCode($code);
		if ($user->{seclev} < $coderef->{seclev} || !exists($form->{"deliverymodes_$code"})) {
			$params{$code} = MSG_MODE_NONE;
		} else {
			$params{$code} = fixint($form->{"deliverymodes_$code"});
		}
	}
	$messages->setPrefs($uid, \%params);

	for (qw(message_threshold messages_interuser_receive)) {
		$prefs{$_} = $form->{$_};
	}
	$slashdb->setUser($uid, \%prefs);

	display_prefs(@_, getData('prefs saved'));
}

sub list_messages {
	my($messages, $constants, $user, $form, $note) = @_;

	my $messagecodes = $messages->getDescriptions('messagecodes');
	my $message_list = $messages->getWebByUID();

	header(getData('header'));
# Spank me, this won't be here for long (aka Pater's cleanup will remove it) -Brian
	print createMenu('users', {
		style =>	'tabbed',
		justify =>	'right',
		color =>	'colored',
		tab_selected =>	'me',
	});
	slashDisplay('user_titlebar', {
		nickname => $user->{nickname},
		uid => $user->{uid},
		tab_selected => 'messages'
	});
	print createMenu('messages'); # [ Message Preferences | Inbox ]
	slashDisplay('list_messages', {
		note		=> $note,
		messagecodes	=> $messagecodes,
		message_list	=> $message_list,
	});
	footer();
}

sub list_message_rss {
	my($messages, $constants, $user, $form) = @_;
	# ...
}

sub display_message {
	my($messages, $constants, $user, $form) = @_;

	my $message = $messages->getWeb($form->{id});

	header(getData('header'));
	slashDisplay('display', {
		message		=> $message,
	});
	footer();
}

sub delete_message {
	my($messages, $constants, $user, $form) = @_;
	my $note;

	if ($messages->_delete_web($form->{id})) {
		$note = getData('delete good', { id => $form->{id} });
	} else {
		$note = getData('delete bad',  { id => $form->{id} });
	}

	list_messages(@_, $note);
}

sub delete_messages {
	my($messages, $constants, $user, $form) = @_;
	my($note, @success, @fail);

	for my $id (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
		if ($messages->_delete_web($id)) {
			push @success, $id;
		} else {
			push @fail, $id;
		}
	}

	$note = getData('deletes', { success => \@success, fail => \@fail });

	list_messages(@_, $note);
}

# etc.

createEnvironment();
main();

1;
