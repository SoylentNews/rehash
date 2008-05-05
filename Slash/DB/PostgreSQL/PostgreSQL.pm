# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DB::PostgreSQL;
use strict;
use Slash::Utility;
use URI ();

use base 'Slash::DB';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our $VERSION = $Slash::Constants::VERSION;

# BENDER: I hate people who love me.  And they hate me.

########################################################
sub deleteUser {
	my($self, $uid) = @_;
	$self->setUser($uid, {
		bio		=> '',
		nickname	=> 'deleted user',
		matchname	=> 'deleted user',
		realname	=> '',
		realemail	=> '',
		fakeemail	=> '',
		newpasswd	=> '',
		passwd		=> '',
		seclev		=> 0
	});
	$self->sqlDo("DELETE FROM users_param WHERE uid=$uid");
}

#################################################################
# Replication issue. This needs to be a two-phase commit.
sub createUser {
	my($self, $matchname, $email, $newuser) = @_;
	return unless $matchname && $email && $newuser;

	return if ($self->sqlSelect(
		"count(uid)", "users",
		"matchname=" . $self->sqlQuote($matchname)
	))[0];
	return if ($self->sqlSelect(
		"count(uid)", "users",
		" realemail=" . $self->sqlQuote($email)
	))[0];

	$self->sqlInsert("users", {
		realemail	=> $email,
		nickname	=> $newuser,
		matchname	=> $matchname,
		passwd		=> encryptPassword(changePassword())
	});
	my($uid) = $self->sqlSelect('uid', 'users', 'nickname=' .
			$self->sqlQuote($newuser)
			);

	return $uid;
}


########################################################
sub countUsersIndexExboxesByBid {
	my($self, $bid) = @_;
	my($count) = $self->sqlSelect("count(*)", "users",
		qq!exboxes like "%'$bid'%" !
	);

	return $count;
}

########################################################
sub getCommentReply {
	my($self, $time, $sid, $pid) = @_;
	my $reply = $self->sqlSelectHashref("$time, subject,comments.points as points,
		comment,realname,nickname,
		fakeemail,homepage,cid,sid,users.uid as uid",
		"comments,users",
		"sid=" . $self->sqlQuote($sid) . "
		AND cid=" . $self->sqlQuote($pid) . "
		AND users.uid=comments.uid"
	);

	return $reply;
}

########################################################
# What an ugly method
sub getSubmissionForUser {
	my($self, $dateformat) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $sql = "SELECT subid,subj,date_format($dateformat,'m/d  H:i'),tid,note,email,name,section,comment,submissions.uid,karma FROM submissions,users_info";
	$sql .= "  WHERE submissions.uid=users_info.uid AND $form->{del}=del AND (";
	$sql .= $form->{note} ? "note=" . $self->sqlQuote($form->{note}) : "isnull(note)";
	$sql .= "		or note=' ' " unless $form->{note};
	$sql .= ")";
	$sql .= "		and tid='$form->{tid}' " if $form->{tid};
	$sql .= "         and section=" . $self->sqlQuote($user->{section}) if $user->{section};
	$sql .= "         and section=" . $self->sqlQuote($form->{section}) if $form->{section};
	$sql .= "	  ORDER BY time";

	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;

	my $submission = $cursor->fetchall_arrayref;

	return $submission;
}


########################################################
# This isn't used anywhere and it's obsoleted by story_heap stuff. -Jamie
#sub getNewstoryTitle {
#	my($self, $storyid, $sid) = @_;
#	my($title) = $self->sqlSelect("title", "newstories",
#		"sid=" . $self->sqlQuote($sid)
#	);
#
#	return $title;
#}



########################################################
sub saveStory {
	my($self) = @_;
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	$self->sqlInsert('storiestuff', { sid => $form->{sid} });
	$self->sqlInsert('discussions', {
		sid	=> $form->{sid},
		title	=> $form->{title},
		ts	=> $form->{'time'},
		url	=> "$constants->{rootdir}/article.pl?sid=$form->{sid}"
	});


	# If this came from a submission, update submission and grant
	# Karma to the user
	my $suid;
	if ($form->{subid}) {
		my($suid) = $self->sqlSelect(
			'uid', 'submissions',
			'subid=' . $self->sqlQuote($form->{subid})
		);

		# i think i got this right -- pudge
		my($userkarma) = $self->sqlSelect('karma', 'users_info', "uid=$suid");
		my $newkarma = (($userkarma + $constants->{submission_bonus})
			> $constants->{maxkarma})
				? $constants->{maxkarma}
				: "karma+$constants->{submission_bonus}";
		$self->sqlUpdate('users_info', { -karma => $newkarma }, "uid=$suid")
			if $suid != $constants->{anonymous_coward_uid};

		$self->sqlUpdate('users_info',
			{ -karma => 'karma + 3' },
			"uid=$suid"
		) if $suid != $constants->{anonymous_coward_uid};

		$self->sqlUpdate('submissions',
			{ del=>2 },
			'subid=' . $self->sqlQuote($form->{subid})
		);
	}

	$self->sqlInsert('stories', {
		sid		=> $form->{sid},
		uid		=> $form->{aid},
		tid		=> $form->{tid},
		dept		=> $form->{dept},
		'time'		=> $form->{'time'},
		title		=> $form->{title},
		section		=> $form->{section},
		bodytext	=> $form->{bodytext},
		introtext	=> $form->{introtext},
		relatedtext	=> $form->{relatedtext},
		displaystatus	=> $form->{displaystatus},
		commentstatus	=> $form->{commentstatus}
	});
	$self->saveExtras($form);
}


##################################################################
# Should this really be in here?
sub getDay {
	my($self) = @_;
	my($now) = $self->sqlSelect("now() - '0000-01-01'::date");
	($now) = split / /, $now;
	$now++;

	return $now;
}



##################################################################
sub setUser {
	my($self, $uid, $hashref) = @_;
	my(@param, %update_tables, $cache);
	my $tables = [qw( users )];
	# special cases for password, exboxes
	if (exists $hashref->{passwd}) {
		# get rid of newpasswd if defined in DB
		$hashref->{newpasswd} = '';
		$hashref->{passwd} = encryptPassword($hashref->{passwd});
	}

	# hm, come back to exboxes later; it works for now
	# as is, since external scripts handle it -- pudge
	# a VARARRAY would make a lot more sense for this, no need to
	# pack either -Brian
	if (0 && exists $hashref->{exboxes}) {
		if (ref $hashref->{exboxes} eq 'ARRAY') {
			$hashref->{exboxes} = sprintf("'%s'", join "','", @{$hashref->{exboxes}});
		} elsif (ref $hashref->{exboxes}) {
			$hashref->{exboxes} = '';
		} # if nonref scalar, just let it pass
	}

	$cache = _genericGetCacheName($self, $tables);

	for (keys %$hashref) {
		(my $clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};
		if ($key) {
			push @{$update_tables{$key}}, $_;
		} else {
			push @param, [$_, $hashref->{$_}];
		}
	}

	for my $table (keys %update_tables) {
		my %minihash;
		for my $key (@{$update_tables{$table}}){
			$minihash{$key} = $hashref->{$key}
				if defined $hashref->{$key};
		}
		$self->sqlUpdate($table, \%minihash, '"uid"=' . $uid, 1);
	}
	# What is worse, a select+update or a replace?
	# I should look into that.
	for (@param)  {
		$self->sqlDo(qq| DELETE FROM users_param where \"uid\"=$uid and name='$_->[0]' |);
		$self->sqlDo(qq| INSERT INTO users_param (uid, name, value) VALUES ($uid, '$_->[0]', '$_->[1]') |);
	}
}

########################################################
# Now here is the thing. We want getUser to look like
# a generic, despite the fact that it is not :)
sub getUser {
	my $answer = _genericGet('users', 'uid', @_);
	my $user = getCurrentAnonymousCoward();
	for (keys %$answer) {
		$user->{$_} = $answer->{$_};
	}
	return $user;
}

########################################################
# You can use this to reset cache's in a timely
# manner :)
sub _genericCacheRefresh {
	my($self, $table,  $expiration) = @_;
	return unless $expiration;
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time = '_' . $table . '_cache_time';
	my $table_cache_full = '_' . $table . '_cache_full';
	return unless $self->{$table_cache_time};
	my $time = time();
	my $diff = $time - $self->{$table_cache_time};

	if ($diff > $expiration) {
		# print STDERR "TIME:$diff:$expiration:$time:$self->{$table_cache_time}:\n";
		$self->{$table_cache} = {};
		$self->{$table_cache_time} = 0;
		$self->{$table_cache_full} = 0;
	}
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGetCache {
	return _genericGet(@_) unless getCurrentStatic('cache_enabled');

	my($table, $table_prime, $self, $id, $values, $cache_flag) = @_;
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';

	my $type;
	if (ref($values) eq 'ARRAY') {
		$type = 0;
	} else {
		$type  = $values ? 1 : 0;
	}

	if ($type) {
		return $self->{$table_cache}{$id}{$values}
			if (keys %{$self->{$table_cache}{$id}} and !$cache_flag);
	} else {
		if (keys %{$self->{$table_cache}{$id}} && !$cache_flag) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		}
	}

	# Lets go knock on the door of the database
	# and grab the data's since it is not cached
	# On a side note, I hate grabbing "*" from a database
	# -Brian
	$self->{$table_cache}{$id} = {};
	my $answer = $self->sqlSelectHashref('*', $table, "$table_prime=" . $self->sqlQuote($id));
	$self->{$table_cache}{$id} = $answer;

	$self->{$table_cache_time} = time();

	if ($type) {
		return $self->{$table_cache}{$id}{$values};
	} else {
		if ($self->{$table_cache}{$id}) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		} else {
			return;
		}
	}
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericClearCache {
	my($table, $self) = @_;
	my $table_cache= '_' . $table . '_cache';

	$self->{$table_cache} = {};
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGet {
	my($table, $table_prime, $self, $id, $val) = @_;
	my($answer, $type);
	my $id_db = $self->sqlQuote($id);

	if (ref($val) eq 'ARRAY') {
		my $values = join ',', @$val;
		$answer = $self->sqlSelectHashref($values, $table, "$table_prime=$id_db");
	} elsif ($val) {
		($answer) = $self->sqlSelect($val, $table, "$table_prime=$id_db");
	} else {
		$answer = $self->sqlSelectHashref('*', $table, "$table_prime=$id_db");
	}

	return $answer;
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGetsCache {
	return _genericGets(@_) unless getCurrentStatic('cache_enabled');

	my($table, $table_prime, $self, $cache_flag) = @_;
	my $table_cache= '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';
	my $table_cache_full= '_' . $table . '_cache_full';

	if (keys %{$self->{$table_cache}} && $self->{$table_cache_full} && !$cache_flag) {
		my %return = %{$self->{$table_cache}};
		return \%return;
	}

	# Lets go knock on the door of the database
	# and grab the data since it is not cached
	# On a side note, I hate grabbing "*" from a database
	# -Brian
	$self->{$table_cache} = {};
	my $sth = $self->sqlSelectMany('*', $table);
	while (my $row = $sth->fetchrow_hashref) {
		$self->{$table_cache}{ $row->{$table_prime} } = $row;
	}
	$self->{$table_cache_full} = 1;
	$sth->finish;
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGets {
	my($table, $table_prime, $self) = @_;

	# Lets go knock on the door of the database
	# and grab the data since it is not cached
	# On a side note, I hate grabbing "*" from a database
	# -Brian
	my %return;
	my $sth = $self->sqlSelectMany('*', $table);
	while (my $row = $sth->fetchrow_hashref) {
		$return{ $row->{$table_prime} } = $row;
	}
	$sth->finish;

	return \%return;
}

########################################################
sub sqlTableExists {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect();
	my $count = $self->{_dbh}->selectrow_array(qq|SELECT count(relname) from pg_class WHERE relname = '$table'|);
	return $count;
}

########################################################
sub sqlSelectColumns {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect();
	my $rows = $self->{_dbh}->selectcol_arrayref("SELECT a.attname FROM pg_class c, pg_attribute a WHERE c.relname = '$table' AND a.attnum > 0 AND a.attrelid = c.oid");
	return $rows;
}

########################################################
# This could be optimized by not making multiple calls
# to getKeys or by fixing getKeys() to return multiple
# values
sub _genericGetCacheName {
	my($self, $tables) = @_;
	my $cache;

	if (ref($tables) eq 'ARRAY') {
		$cache = '_' . join ('_', sort(@$tables), 'cache_tables_keys');
		unless (keys %{$self->{$cache}}) {
			for my $table (@$tables) {
				my $keys = $self->getKeys($table);
				for (@$keys) {
					$self->{$cache}{$_} = $table;
				}
			}
		}
	} else {
		$cache = '_' . $tables . 'cache_tables_keys';
		unless (keys %{$self->{$cache}}) {
			my $keys = $self->getKeys($tables);
			for (@$keys) {
				$self->{$cache}{$_} = $tables;
			}
		}
	}
	return $cache;
}

1;

__END__

=head1 NAME

Slash::DB::PostgreSQL - PostgreSQL Interface for Slash

=head1 SYNOPSIS

	use Slash::DB::PostgreSQL;

=head1 DESCRIPTION

No documentation yet. Sue me.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut
