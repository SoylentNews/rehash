#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use JSON;
use Slash;
use Slash::Utility;
use Slash::Constants qw(:web :messages);
use Data::Dumper;
use Slash::API;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $api = Slash::API->new;
	# lc just in case

	my $endpoint = lc($form->{m});

	my $endpoints = {
		user		=> {
			function	=> \&user,
			seclev		=> 1,
		},
		comment		=> {
			function	=> \&comment,
			seclev		=> 1,
		},
		story		=> {
			function	=> \&story,
			seclev		=> 1,
		},
		auth		=> {
			function	=> \&auth,
			seclev		=> 1,
		},
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},

	};

	$endpoint = 'default' unless $endpoints->{$endpoint};

	my $retval = $endpoints->{$endpoint}{function}->($form, $slashdb, $user, $constants);

	binmode(STDOUT, ':encoding(utf8)');
	$api->header;
	print $retval;
}

sub user {
	my ($form, $slashdb, $user, $constants) = @_;
	my $api = Slash::API->new;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		max_uid		=> {
			function	=> \&maxUid,
			seclev		=> 1,
		},
		get_uid		=> {
			function	=> \&nameToUid,
			seclev		=> 1,
		},
		get_nick	=> {
			function	=> \&uidToName,
			seclev		=> 1,
		},
		get_user	=> {
			function	=> \&getPubUserInfo,
			seclev		=> 1,
		},
	};
	return $ops->{$op}{function}->($form, $slashdb, $user, $constants);
}

sub nullop {
	return "";
}

sub maxUid {
	my ($form, $slashdb, $user, $constants) = @_;
	my $slashdb = getCurrentDB();
	my $json = JSON->new->utf8->allow_nonref;
	my $max = {};
	$max->{max_uid} = $slashdb->sqlSelect(
					'max(uid)',
					'users');
	return $json->encode($max);
}

sub nameToUid {
	my ($form, $slashdb, $user, $constants) = @_;
	my $slashdb = getCurrentDB();
	my $json = JSON->new->utf8->allow_nonref;
	my $nick = $slashdb->sqlQuote($form->{nick});
	my $uid = {};
	$uid->{uid} = $slashdb->sqlSelect(
					'uid',
					'users',
					" nickname = $nick ");
	return $json->encode($uid);
}

sub uidToName {
	my ($form, $slashdb, $user, $constants) = @_;
	my $slashdb = getCurrentDB();
	my $json = JSON->new->utf8->allow_nonref;
	my $uid = $form->{uid};
	my $nick = {};
	$nick->{nick} = $slashdb->sqlSelect(
					'nickname',
					'users',
					" uid = $uid ");
	return $json->encode($nick);
}

sub getPubUserInfo {
}

#createEnvironment();
main();
1;
