#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::Zoo;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $zoo   = getObject('Slash::Zoo');
	my $constants = getCurrentStatic();
	my $slashdb   = getCurrentDB();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	# require POST and logged-in user for these ops
	my $user_ok   = $user->{state}{post} && !$user->{is_anon};

	# possible value of "op" parameter in form
	my %ops = (
		confirm		=> [ 1,		\&confirm		], # formkey?
		add		=> [ $user_ok,		\&add		], # formkey?
		'delete'		=> [ $user_ok,		\&dekete		], # formkey?
		friends		=> [ 1,			\&friends		],
		fans		=> [ 1,			\&fans		],
		foes		=> [ 0,			\&list		],
		freaks		=> [ 0,			\&list		],
		editfriend		=> [ $user_ok,			\&edit		],
		editfoe		=> [ $user_ok,			\&edit		],
		default		=> [ 0,			\&list	],
	);

	my $op = $form->{'op'};
	print STDERR "OP $op\n";
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		redirect($constants->{rootdir});
		return;
	}

	# hijack RSS feeds
	if ($form->{content_type} eq 'rss') {
		# Do nothing for the moment.
	} else {
		$ops{$op}[FUNCTION]->($zoo, $constants, $user, $form, $slashdb);
		footer();
	}
}

sub list {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	_printHead("mainhead");

	my $friends = $zoo->getFriends($user->{uid});
	if (@$friends) {
		slashDisplay('plainlist', { friends => $friends });
	} else {
		print getData('nofriends');
	}
}

sub friends {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	_printHead("friendshead", { nickname => $form->{nick} });
	
	my $uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
	my $friends = $zoo->getFriends($uid);
	my $editable = ($uid == $user->{uid} ? 1 : 0);
	if (@$friends) {
		slashDisplay('plainlist', { friends => $friends, editable => $editable });
	} else {
		print getData('nofriends', { nickname => $form->{nick}});
	}
}

sub fans {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	_printHead("fanshead",{ nickname => $form->{nick} });

	my $uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
	my $friends = $zoo->getFans($uid);
	my $editable = ($uid == $user->{uid} ? 1 : 0);
	if (@$friends) {
		slashDisplay('plainlist', { friends => $friends, editable => $editable });
	} else {
		print getData('nofans', { nickname => $form->{nick}});
	}
}


sub addFriend {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	$zoo->addFriend($user->{uid}, $form->{uid}) if $form->{uid};
	displayFriends(@_);
}

sub deleteFriend {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	for my $uid (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
		$zoo->deleteFriend($user->{uid}, $uid);
	}

	displayFriends(@_);
}


sub _validFormkey {
	my $error;
	# this is a hack, think more on it, OK for now -- pudge
	Slash::Utility::Anchor::getSectionColors();
	for (qw(max_post_check interval_check formkey_check)) {
		last if formkeyHandler($_, 0, 0, \$error);
	}

	if ($error) {
		_printHead("mainhead");
		print $error;
		return 0;
	} else {
		# why does anyone care the length?
		getCurrentDB()->updateFormkey(0, length(getCurrentForm()->{article}));
		return 1;
	}
}

sub _printHead {
	my($head, $data) = @_;
	my $title = getData($head, $data);
	header($title);
	slashDisplay("zoohead", { title => $title });
}

createEnvironment();
main();
1;
