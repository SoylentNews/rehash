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
		add		=> [ $user_ok,		\&add		], # formkey?
		'delete'		=> [ $user_ok,		\&delete		], # formkey?
		addcheck		=> [ $user->{seclev},		\&check		], # formkey?
		'deletecheck'		=> [ $user->{seclev},		\&check		], # formkey?
		friends		=> [ 1,			\&friends		],
		fans		=> [ 1,			\&fans		],
		foes		=> [ 1,			\&foes		],
		freaks		=> [ 1,			\&freaks		],
		default		=> [ 0,			\&list	],
	);

	my $op = $form->{'op'};
	print STDERR "OP $op\n";
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		redirect($constants->{rootdir});
		return;
	}

	$ops{$op}[FUNCTION]->($zoo, $constants, $user, $form, $slashdb);
	footer()
		unless ($form->{content_type} eq 'rss');
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

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $friends = $zoo->getFriends($uid); 
		
	if ($form->{content_type} eq 'rss') {
		_rss($friends, $nick, 'friends');
	} else {
		if ($editable) {
			_printHead("yourfriendshead");
		} else {
			_printHead("friendshead", { nickname => $nick });
		}
		
		if (@$friends) {
			slashDisplay('plainlist', { people => $friends, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofriends');
			} else {
				print getData('nofriends', { nickname => $nick });
			}
		}
	}
}

sub foes {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $foes = $zoo->getFoes($uid); 

	if ($form->{content_type} eq 'rss') {
		_rss($foes, $nick, 'foes');
	} else {
		if ($editable) {
			_printHead("yourfoeshead");
		} else {
			_printHead("foeshead", { nickname => $nick });
		}
		
		if (@$foes) {
			slashDisplay('plainlist', { people => $foes, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofoes');
			} else {
				print getData('nofoes', { nickname => $nick });
			}
		}
	}
}

sub fans {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}
	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $fans = $zoo->getFans($uid);

	if ($form->{content_type} eq 'rss') {
		_rss($fans, $nick, 'fans');
	} else {
		if ($editable) {
			_printHead("yourfanshead");
		} else {
			_printHead("fanshead",{ nickname => $nick });
		}
		if (@$fans) {
			slashDisplay('plainlist', { people => $fans, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofans');
			} else {
				print getData('nofans', { nickname => $nick });
			}
		}
	}
}

sub freaks {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}
	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $freaks = $zoo->getFreaks($uid);

	if ($form->{content_type} eq 'rss') {
		_rss($freaks, $nick, 'freaks');
	} else {
		if ($editable) {
			_printHead("yourfreakshead");
		} else {
			_printHead("freakshead",{ nickname => $nick });
		}
		if (@$freaks) {
			slashDisplay('plainlist', { people => $freaks, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofreaks');
			} else {
				print getData('nofreaks', { nickname => $nick });
			}
		}
	}
}


sub add {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	if ($form->{uid}) {
		if ($form->{type} eq 'foe') {
			$zoo->setFoe($user->{uid}, $form->{uid});
		} elsif ($form->{type} eq 'friend') {
			$zoo->setFriend($user->{uid}, $form->{uid});
		}
	}
	# This is just to make sure the next view gets it right
	if ($form->{type} eq 'foe') {
		redirect($constants->{rootdir} . "/my/foes/");
		return;
	} else {
		redirect($constants->{rootdir} . "/my/friends/");
		return;
	}
}

sub delete {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	if ($form->{uid}) {
		$zoo->delete($user->{uid}, $form->{uid});
	} else {
		for my $uid (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
			$zoo->delete($user->{uid}, $uid);
		}
	}
	# This is just to make sure the next view gets it right
	if ($form->{type} eq 'foe') {
		redirect($constants->{rootdir} . "/my/foes/");
		return;
	} else {
		redirect($constants->{rootdir} . "/my/friends/");
		return;
	}
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

sub check {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	if ($form->{uid} && $form->{type}) {
		if ($zoo->count() > $constants->{people_max}) {
			_printHead("mainhead");
			print getData("over_socialized");
		}
		
		my $nickname = $slashdb->getUser($form->{uid}, 'nickname');
		_printHead("mainhead");
		my $template = ($form->{op} eq 'addcheck') ? 'add' : 'delete';
		slashDisplay($template, { 
			uid => $form->{uid},
			nickname => $nickname,
			type => $form->{type}
			 });
	} 
}


sub _printHead {
	my($head, $data) = @_;
	my $title = getData($head, $data);
	header($title);
	slashDisplay("zoohead", { title => $title });
}

sub _rss {
	my ($entries, $nick, $type) = @_;
	my $constants = getCurrentStatic();
	my @items;
	for my $entry (@$entries) {
		push @items, {
			title	=> $entry->[1],
			'link'	=> ($constants->{absolutedir} . '/~' . fixparam($entry->[1])  . "/"),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} $nick's ${type}",
			'link'		=> "$constants->{absolutedir}/",
			description	=> "$constants->{sitename} $nick's ${type}",
		},
		image	=> 1,
		items	=> \@items
	});
}

createEnvironment();
main();
1;
