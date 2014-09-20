#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web :people :messages);
use Slash::Display;
use Slash::Utility;
use Slash::Zoo;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $zoo		= getObject('Slash::Zoo');
	my $constants	= getCurrentStatic();
	my $slashdb	= getCurrentDB();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
	my $gSkin	= getCurrentSkin();

	# require POST and logged-in user for these ops
	# we could move even this out to reskeys ... but right now, no real reason to
	my $user_ok   = $user->{state}{post};

	# possible value of "op" parameter in form
	my %ops = (
		action	=> [ $user_ok,	\&action  ],
		check	=> [ 1,		\&check   ],
		all	=> [ 1,		\&people  ],
		max	=> [ 1,		\&max  ],
	);

	$ops{$_} = $ops{action} for qw(add delete);
	$ops{$_} = $ops{check}  for qw(addcheck deletecheck);
	$ops{$_} = $ops{all}    for qw(friends fans foes freaks fof eof);

	my $op = $form->{'op'};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	# We really should have a $zoo_reader that we also pass to
	# these functions. - Jamie

	$ops{$op}[FUNCTION]->($zoo, $constants, $user, $form, $slashdb, $gSkin);
	my $r;
	if ($r = Apache->request) {
		return if $r->header_only;
	}
	footer() unless $form->{content_type} && $form->{content_type} =~ $constants->{feed_types};
}

sub people {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my %main_vars = (
		friends	=> { constant => FRIEND },
		fans	=> { constant => FAN    },
		foes	=> { constant => FOE    },
		freaks	=> { constant => FREAK  },
		fof	=> { constant => FOF,
			name1	=> 'friends',
			name2	=> 'friendsoffriends',
		},
		eof	=> { constant => EOF,
			name1	=> 'friends',
			name2	=> 'friendsenemies',
		},
		all	=> { constant => undef,
			op	=> 'people',
			name1	=> undef,
			name2	=> 'all',
		},
	);

	my $zoo_vars = $main_vars{$form->{op}};
	$zoo_vars->{op}    ||= $form->{op};
	$zoo_vars->{name1} ||= $form->{op};
	$zoo_vars->{name2} ||= $form->{op};
	$zoo_vars->{head1} ||= "your$zoo_vars->{name2}head";
	$zoo_vars->{head2} ||= "$zoo_vars->{name2}head";
	$zoo_vars->{no1}   ||= "yourno$zoo_vars->{name2}";
	$zoo_vars->{no2}   ||= "no$zoo_vars->{name2}";

	my($uid, $nick);
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
	my $people = $zoo->getRelationships($uid, $zoo_vars->{constant});

	if ($form->{content_type} && $form->{content_type} =~ $constants->{feed_types}) {
		_rss($people, $nick, $zoo_vars->{op});
	} else {
		my $implied;
		if ($editable) {
			_printHead($zoo_vars->{head1}, {
				nickname	=> $nick,
				uid		=> $uid,
				tab_selected_1	=> 'me',
				tab_selected_2	=> $zoo_vars->{name1},
			}) or return;
			$implied = $zoo_vars->{constant};
			
		} else {
			_printHead($zoo_vars->{head2}, {
				nickname	=> $nick,
				uid		=> $uid,
				tab_selected_1	=> 'otheruser',
				tab_selected_2	=> $zoo_vars->{name1},
			}) or return;
		}

		if (@$people) {
			slashDisplay('plainlist', {
				people		=> $people,
				editable	=> $editable,
				implied		=> $implied,
				nickname	=> $nick
			});
		} else {
			if ($editable) {
				print getData($zoo_vars->{no1});
			} else {
				print getData($zoo_vars->{no2}, {
					nickname	=> $nick,
					uid		=> $uid
				});
			}
		}
	}

	# Store the new user we're looking at, if any.
	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}

	return 1;
}

sub max {
	my($zoo, $constants, $user, $form, $slashdb) = @_;
	my $max_uid = $slashdb->countUsers({ max => 1 });
	
	my $max_user = $slashdb->getUser($max_uid);
	
	my $max_title = "Max User";
	header($max_title) or return;
	
	slashDisplay('max', {
		max_title		=> $max_title,
		max_uid	=> $max_uid,
		max_nick	=> $max_user->{nickname}
	});
	return 1;
}

sub action {
	my($zoo, $constants, $user, $form, $slashdb, $gSkin) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('zoo');
	unless ($rkey->use) {
		_printHead('mainhead', { errstr => $rkey->errstr, rkey => $rkey }) or return;
		use Data::Dumper;
		print STDERR Dumper({ reskey => $rkey });
		return 1;
	}

	if ($form->{uid} == $user->{uid} || $form->{uid} == $constants->{anonymous_coward_uid}) {
		_printHead('mainhead', { nickname => $user->{nick}, uid => $user->{uid} }) or return;
		print getData('no_go');
		return 1;
	} else {
		if (testSocialized($zoo, $constants, $user) && ($form->{type} ne 'neutral' || $form->{op} eq 'delete' )) {
			_printHead('mainhead', { nickname => $user->{nick}, uid => $user->{uid} }) or return;
			print getData('no_go');
			return 1;
		}

		my @uids;
		if ($form->{uid}) {
			@uids = ($form->{uid});
		} else {
			@uids = grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form;
		}

		if ($form->{op} eq 'delete' || $form->{type} eq 'neutral') {
			for my $uid (@uids) {
				$zoo->delete($user->{uid}, $uid);
			}

		} else {
			if ($form->{uid}) {
				# no multiples
				@uids = ($uids[0]);
				if ($form->{type} eq 'foe') {
					$zoo->setFoe($user->{uid}, $form->{uid});
				} elsif ($form->{type} eq 'friend') {
					$zoo->setFriend($user->{uid}, $form->{uid});
				}
			}
		}

		# send message here
		# how do we know the operation (setFriend, SetFoe, delete) above succeeded?
		my $messages = getObject('Slash::Messages');
		if ($messages && $form->{type} =~ /^(?:neutral|friend|foe)$/) {
			my $muids = $messages->checkMessageCodes(MSG_CODE_ZOO_CHANGE, \@uids);
			for my $uid (@$muids) {
				my $data  = {
					template_name	=> 'zoo_msg',
					subject		=> { template_name => 'zoo_msg_subj' },
					type		=> $form->{type},
					zoo_user	=> {
						map { ($_ => $user->{$_}) } qw(uid nickname) # any other user info?
					}
					# do templates need any other information?
				};

				$messages->create($uid, MSG_CODE_ZOO_CHANGE, $data, 0, '', 'collective');
			}
		}


	}

	# This is just to make sure the next view gets it right
	if ($form->{type} eq 'foe') {
		redirect("$gSkin->{rootdir}/my/foes");
	} else {
		redirect("$gSkin->{rootdir}/my/friends");
	}

	return 1;
}

sub check {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('zoo');
	unless ($rkey->create) {
		_printHead('mainhead', { errstr => $rkey->errstr, rkey => $rkey }) or return;
		use Data::Dumper;
		print STDERR Dumper({ reskey => $rkey });
		return 1;
	}

	my $uid = $form->{uid} || '';
	my $nickname = $slashdb->getUser($uid, 'nickname');

	if (!$uid || $nickname eq '') {
        	# See comment in plugins/Journal/journal.pl for its call of
        	# getSkinColors() as well.
                Slash::Utility::Anchor::getSkinColors();

		my $title = getData('no_uid');
		header($title) or return;
		print $title;
		return 1;
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

	_printHead('confirm', {
		nickname	=> $nickname,
		uid		=> $uid,
		tab_selected_1	=> ($uid == $user->{uid} ? 'me' : 'otheruser'),
		tab_selected_2	=> 'relation'
	}) or return;

	if ($uid == $user->{uid} || $uid == $constants->{anonymous_coward_uid}  ) {
		print getData('no_go');
		return 1;
	}

	my(%mutual, @mutual);
	if ($user->{people}{FOF()}{$uid}) {
		for my $person (keys %{$user->{people}{FOF()}{$uid}}) {
			next unless $person;
			push @{$mutual{FOF()}}, $person;
			push @mutual, $person;
		}
	}

	if ($user->{people}{EOF()}{$uid}) {
		for my $person (keys %{$user->{people}{EOF()}{$uid}}) {
			next unless $person;
			push @{$mutual{EOF()}}, $person;
			push @mutual, $person;
		}
	}

	my $uids_2_nicknames = $slashdb->getUsersNicknamesByUID(\@mutual)
		if scalar(@mutual);

	my $type = $user->{people}{FOE()}{$uid} ? 'foe': ($user->{people}{FRIEND()}{$uid}? 'friend' :'neutral');

	slashDisplay('confirm', { 
		uid			=> $uid,
		nickname		=> $nickname,
		type			=> $type,
		over_socialized		=> testSocialized($zoo, $constants, $user),
		uids_2_nicknames	=> $uids_2_nicknames,
		mutual 			=> \%mutual,
		rkey			=> $rkey,
	});

	# Store the new user we're looking at, if any.
	if ($user_change && keys %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}

	return 1;
}

sub _printHead {
	my($head, $data) = @_;
	my $slashdb = getCurrentDB();

	# See comment in plugins/Journal/journal.pl for its call of
	# getSkinColors() as well.
	Slash::Utility::Anchor::getSkinColors();

	my $user = getCurrentUser();
	my $useredit = $data->{uid}
		? $slashdb->getUser($data->{uid})
		: $user;

	$data->{user} = $user;
	$data->{useredit} = $useredit;

	my $title = getData($head, $data);
	$data->{title} = $title;
	header($title) or return;
	$data->{tab_selected_1} ||= 'me';
	slashDisplay('zoohead', $data);
}

sub _rss {
	my($entries, $nick, $type) = @_;
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	my @items;
	for my $entry (@$entries) {
		push @items, {
			title	=> $entry->[1],
			'link'	=> ($gSkin->{absolutedir} . '/~' . fixparam($entry->[1])  . '/'),
		};
	}

	xmlDisplay($form->{content_type} => {
		channel => {
			title		=> "$constants->{sitename} $nick's ${type}",
			'link'		=> "$gSkin->{absolutedir}/",
			description	=> "$constants->{sitename} $nick's ${type}",
		},
		image	=> 1,
		items	=> \@items,
		rdfitemdesc => 1,
	});
}

sub testSocialized {
	my($zoo, $constants, $user) = @_;
	return 0 if $user->{is_admin};

	if ($user->{is_subscriber} && $constants->{people_max_subscriber}) {
		return ($zoo->count($user->{uid}) > $constants->{people_max_subscriber}) ? 1 : 0;
	} else {
		return ($zoo->count($user->{uid}) > $constants->{people_max}) ? 1 : 0;
	}
}

createEnvironment();
main();
1;
