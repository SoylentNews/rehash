#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web :people);
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
	my $formname = 'zoo';
	my $formkey = $form->{formkey};

	# require POST and logged-in user for these ops
	my $user_ok   = $user->{state}{post} && !$user->{is_anon};

	# possible value of "op" parameter in form
	my $ops = {
		action		=> { 
			check => $user_ok,		
			formkey    => ['formkey_check', 'valid_check'],
			function => \&action		
		},
		add		=> { 
			check => $user_ok,		
			formkey    => ['formkey_check', 'valid_check'],
			function => \&action		
		},
		'delete'		=> { 
			check => $user_ok,		
			formkey    => ['formkey_check', 'valid_check'],
			function => \&action		
		},
		addcheck		=> { 
			check => $user->{seclev},		
			formkey    => ['generate_formkey'],
			function => 	\&check		
		}, 
		deletecheck		=> { 
			check => $user->{seclev},		
			formkey    => ['generate_formkey'],
			function => \&check		
		},
		check		=> { 
			check => $user->{seclev},		
			formkey    => ['generate_formkey'],
			function => \&check		
		},
		friends		=> { 
			check => 1,			
			function => \&friends		
		},
		fans		=> { 
			check => 1,			
			function => \&fans		
		},
		foes		=> { 
			check => 1,			
			function => \&foes		
		},
		freaks		=> { 
			check => 1,			
			function => \&freaks		
		},
		fof		=> { 
			check => 1,			
			function => \&fof		
		},
		'eof'		=> { 
			check => 1,			
			function => \&enof		
		},
		all		=> { 
			check => 1,			
			function => \&all		
		},
		default		=> { 
			check => 0,			
			function => \&list	
		},
	};

	my ($note, $error_flag);
	my $op = $form->{'op'};
	if ($user->{seclev} < 100) {
		if ($ops->{$op}{formkey}) {
			for my $check (@{$ops->{$op}{formkey}}) {
				$error_flag = formkeyHandler($check, $formname, $formkey, \$note);
				$ops->{$op}{update_formkey} = 1 if $check eq 'formkey_check';
				last if $error_flag;
			}
		}
	}
	if ($error_flag) {
		header();
		print $note;
		footer();
		return;
	}

	if ($ops->{$op}{update_formkey} && $user->{seclev} < 100 && ! $error_flag) {
		# successful save action, no formkey errors, update existing formkey
		# why assign to an unused variable? -- pudge
		my $updated = $slashdb->updateFormkey($formkey, length($ENV{QUERY_STRING}));
	}
	errorLog("zoo.pl error_flag '$error_flag'") if $error_flag;

	if (!$op || !exists $ops->{$op} || !$ops->{$op}->{check}) {
		redirect($constants->{rootdir});
		return;
	}

	$ops->{$op}->{function}->($zoo, $constants, $user, $form, $slashdb);
	footer()
		unless ($form->{content_type} eq 'rss');
}

sub list {
	my($zoo, $constants, $user, $form, $slashdb) = @_;
	# This was never linked to, but basically we send people to search who try to just hit the blank URL
	# -Brian
	redirect("$constants->{rootdir}/search.pl?op=users");
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

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $friends = $zoo->getRelationships($uid, FRIEND);
		
	if ($form->{content_type} eq 'rss') {
		_rss($friends, $nick, 'friends');
	} else {
		my $implied;
		if ($editable) {
			_printHead("yourfriendshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> 'friends'
			});
			$implied = FRIEND;
		} else {
			_printHead("friendshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> 'friends'
			});
		}
		
		if (@$friends) {
			slashDisplay('plainlist', {
				people => $friends,
				editable => $editable,
				implied => $implied,
				nickname => $nick
			});
		} else {
			if ($editable) {
				print getData('yournofriends');
			} else {
				print getData('nofriends', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}       
}

sub fof {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $friends = $zoo->getRelationships($uid, FOF);
		
	if ($form->{content_type} eq 'rss') {
		_rss($friends, $nick, 'fof');
	} else {
		my $implied;
		if ($editable) {
			_printHead("yourfriendsoffriendshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> 'friends'
			});
			$implied = FOF;
		} else {
			_printHead("friendsoffriendshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> 'friends'
			});
		}
		
		if (@$friends) {
			slashDisplay('plainlist', {
				people => $friends,
				editable => $editable,
				implied => $implied,
				nickname => $nick
			});
		} else {
			if ($editable) {
				print getData('yournofriendsoffriends');
			} else {
				print getData('nofriendsoffriends', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}       
}

sub enof {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $friends = $zoo->getRelationships($uid, EOF);
		
	if ($form->{content_type} eq 'rss') {
		_rss($friends, $nick, 'friends');
	} else {
		my $implied;
		if ($editable) {
			_printHead("yourfriendsenemieshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> 'friends',
			});
			$implied = EOF;
		} else {
			_printHead("friendsenemieshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> 'friends',
			});
		}
		
		if (@$friends) {
			slashDisplay('plainlist', { people => $friends, editable => $editable, implied => $implied, nickname => $nick });
		} else {
			if ($editable) {
				print getData('yournofriendsenemies');
			} else {
				print getData('nofriendsenemies', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
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

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $foes = $zoo->getRelationships($uid, FOE);

	if ($form->{content_type} eq 'rss') {
		_rss($foes, $nick, 'foes');
	} else {
		my $implied;
		if ($editable) {
			_printHead("yourfoeshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> 'foes',
			});
			$implied = FOE;
		} else {
			_printHead("foeshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> 'foes',
			});
		}
		
		if (@$foes) {
			slashDisplay('plainlist', { people => $foes, editable => $editable, implied => $implied, nickname => $nick });
		} else {
			if ($editable) {
				print getData('yournofoes');
			} else {
				print getData('nofoes', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
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

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $fans = $zoo->getRelationships($uid, FAN);

	if ($form->{content_type} eq 'rss') {
		_rss($fans, $nick, 'fans');
	} else {
		my $implied;
		if ($editable) {
			_printHead("yourfanshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> 'fans',
			});
			$implied = FAN;
		} else {
			_printHead("fanshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> 'fans',
			});
		}
		if (@$fans) {
			slashDisplay('plainlist', { people => $fans, editable => $editable, implied => $implied, nickname => $nick });
		} else {
			if ($editable) {
				print getData('yournofans');
			} else {
				print getData('nofans', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
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

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $freaks = $zoo->getRelationships($uid, FREAK);

	if ($form->{content_type} eq 'rss') {
		_rss($freaks, $nick, 'freaks');
	} else {
		my $implied;
		if ($editable) {
			_printHead("yourfreakshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> 'freaks',
			});
			$implied = FREAK;
			
		} else {
			_printHead("freakshead", {
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> 'freaks',
			});
		}
		if (@$freaks) {
			slashDisplay('plainlist', { people => $freaks, editable => $editable, implied => $implied, nickname => $nick });
		} else {
			if ($editable) {
				print getData('yournofreaks');
			} else {
				print getData('nofreaks', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}       
}

sub all {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $people = $zoo->getRelationships($uid);

	if ($form->{content_type} eq 'rss') {
		_rss($people, $nick, 'people');
	} else {
		if ($editable) {
			_printHead("yourall", { # this doesn't look right to me - Jamie
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'me',
			});
		} else {
			_printHead("yourhead", { # this doesn't look right to me - Jamie
				nickname => $nick,
				uid => $uid,
				tab_selected_1	=> 'otheruser',
			});
		}
		if (@$people) {
			slashDisplay('plainlist', { people => $people, editable => $editable, nickname => $nick });
		} else {
			if ($editable) {
				print getData('yournoall');
			} else {
				print getData('noall', { nickname => $nick, uid => $uid });
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}       
}

sub action {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	if ($form->{uid} == $user->{uid} || $form->{uid} == $constants->{anonymous_coward_uid}  ) {
		_printHead("mainhead", { nickname => $user->{nick}, uid => $user->{uid} });
		print getData("no_go");
		return;
	} else {
		if (testSocialized($zoo, $constants, $user) && ($form->{type} ne 'neutral' || $form->{op} eq 'delete' )) {
			print getData("no_go");
			return 0;
		}
		if ( $form->{op} eq 'delete' || $form->{type} eq 'neutral') {
			if ($form->{uid}) {
				$zoo->delete($user->{uid}, $form->{uid});
			} else {
				for my $uid (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
					$zoo->delete($user->{uid}, $uid);
				}
			}
		} else {
			if ($form->{uid}) {
				if ($form->{type} eq 'foe') {
					$zoo->setFoe($user->{uid}, $form->{uid});
				} elsif ($form->{type} eq 'friend') {
					$zoo->setFriend($user->{uid}, $form->{uid});
				}
			}
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

sub check {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my $uid = $form->{uid} || "";
	if (!$uid) {
		print getData("no_uid");
		return;
	}

	my $nickname = $slashdb->getUser($uid, 'nickname');
	my $user_change = { };
	if ($uid != $user->{uid} && !isAnon($uid) && !$user->{is_anon}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
	}
	_printHead("confirm", {
		nickname	=> $nickname,
		uid		=> $uid,
		tab_selected_1	=> ($uid == $user->{uid} ? 'me' : 'otheruser'),
		tab_selected_2	=> 'relation'
	});
	if ($uid == $user->{uid} || $uid == $constants->{anonymous_coward_uid}  ) {
		print getData("no_go");
		return 0;
	}

#	my (%mutual, @mutual);
#	for my $rel (keys %{$user->{people}}) {
#		for my $person (keys %{$user->{people}{$rel}}) {
#			if ($compare->{$rel}{$person}) {
#				push @{$mutual{$rel}}, $person;
#				push @mutual, $person;
#			}
#		}
#	}
	my (%mutual, @mutual);
	if ($user->{people}{FOF()}{$uid}) {
		for my $person (keys %{$user->{people}{FOF()}{$uid}}) {
			push @{$mutual{FOF()}}, $person;
			push @mutual, $person;
		}
	}
	if ($user->{people}{EOF()}{$uid}) {
		for my $person (keys %{$user->{people}{EOF()}{$uid}}) {
			push @{$mutual{EOF()}}, $person;
			push @mutual, $person;
		}
	}
	my $uids_2_nicknames = $slashdb->getUsersNicknamesByUID(\@mutual)
		if @mutual;

	my $type = $user->{people}{FOE()}{$uid} ? 'foe': ($user->{people}{FRIEND()}{$uid}? 'friend' :'neutral');
	slashDisplay('confirm', { 
		uid => $uid,
		nickname => $nickname,
		type => $type,
		over_socialized => testSocialized($zoo, $constants, $user),
		uids_2_nicknames => $uids_2_nicknames,
		mutual => \%mutual
	});

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}       
}

sub _printHead {
	my($head, $data) = @_;
	my $slashdb = getCurrentDB();
	# See comment in plugins/Journal/journal.pl for its call of
	# getSectionColors() as well.
	Slash::Utility::Anchor::getSectionColors();
	my $user = getCurrentUser();
	my $useredit = $data->{uid}
		? $slashdb->getUser($data->{uid})
		: $user;
	$data->{user} = $user;
	$data->{useredit} = $useredit;
	my $title = getData($head, $data);
	$data->{title} = $title;
	header($title);
	$data->{tab_selected_1} ||= 'me';
	slashDisplay("zoohead", $data);
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

sub testSocialized {
	my ($zoo, $constants, $user) = @_;
	return 0 
		if $user->{is_admin};
	if ($user->{is_subscriber} && $constants->{people_max_subscriber}) {
		return ($zoo->count($user->{uid}) > $constants->{people_max_subscriber}) ? 1 : 0;
	} else {
		return ($zoo->count($user->{uid}) > $constants->{people_max}) ? 1 : 0;
	}
}

createEnvironment();
main();
1;
