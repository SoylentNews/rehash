# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Stats;

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Stats'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

########################################################
sub createStatDaily {
	my($self, $day, $name, $value) = @_;
	$value = 0 unless $value;

	$self->sqlInsert('stats_daily', {
			'day' => $day,
			'name' => $name,
			'value' => $value,
	}, { ignore => 1 });
}

########################################################
sub getPoints {
	my($self) = @_;
	return $self->sqlSelect('SUM(points)', 'users_comments');
}

########################################################
sub getAdminsClearpass {
	my($self) = @_;
	return $self->sqlSelectAllHashref(
		"nickname",
		"nickname, value",
		"users, users_param",
		"users.uid = users_param.uid
			AND users.seclev > 1
			AND users_param.name='admin_clearpass'
			AND users_param.value",
		"LIMIT 999"
	);
}

########################################################
sub countModeratorLog {
	my($self, $yesterday) = @_;

	my $used = $self->sqlCount(
		'moderatorlog', 
		"ts BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'"
	);
}

########################################################
sub getCommentsByDistinctIPID {
	my($self, $yesterday) = @_;

	my $used = $self->sqlSelectColArrayref(
		'ipid', 'comments', 
		"date BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'",
		'',
		{distinct => 1}
	);
}

########################################################
sub countSubmissionsByDay {
	my($self, $yesterday) = @_;

	my $used = $self->sqlCount(
		'submissions', 
		"time BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'"
	);
}

########################################################
sub countSubmissionsByCommentIPID {
	my($self, $yesterday, $ipids) = @_;
	return unless @$ipids;
	my $slashdb = getCurrentDB();
	my $in_list = join(",", map { $slashdb->sqlQuote($_) } @$ipids);

	my $used = $self->sqlCount(
		'submissions', 
		"(time BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59') AND ipid IN ($in_list)"
	);
}

########################################################
sub countModeratorLogHour {
	my($self, $yesterday) = @_;

	my $modlog_hr = $self->sqlSelectAllHashref(
		"val",
		"val, COUNT(*) AS count",
		"moderatorlog",
		"ts BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'",
		"GROUP BY val"
	);
	
	return $modlog_hr;
}

########################################################
sub countCommentsDaily {
	my($self, $yesterday) = @_;

	# Count comments posted yesterday... using a primary key,
	# if it'll save us a table scan.  On Slashdot this cuts the
	# query time from about 12 seconds to about 0.8 seconds.
	my $max_cid = $self->sqlSelect("MAX(cid)", "comments");
	my $cid_limit_clause = "";
	if ($max_cid > 300_000) {
		# No site can get more than 100K comments a day.
		# It is decided.  :)
		$cid_limit_clause = "cid > " . ($max_cid-100_000)
			. " AND ";
	}
	my $comments = $self->sqlSelect(
		"COUNT(*)",
		"comments",
		"$cid_limit_clause date BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'"
	);

	return $comments; 
}

########################################################
sub countDailyComments {
	my($self, $yesterday) = @_;
	$self->sqlSelect("count(*)", "accesslog",
		"op='comments' AND BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59' GROUP BY op");
}

########################################################
sub countDailyArticles {
	my($self, $yesterday) = @_;
	$self->sqlSelect("count(*)", "accesslog",
		"op='comments' AND BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'",
	 'GROUP BY op');
}

########################################################
sub countDailyCommentsByDistinctIPID {
	my($self, $yesterday) = @_;
	$self->sqlSelect("count(*)", "accesslog",
		"op='comments' AND BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'", 
		'GROUP BY op',
		{distinct => 1});
}

########################################################
sub countDailyArticlesByDistinctIPID {
	my($self, $yesterday) = @_;
	$self->sqlSelect("count(*)", "accesslog",
		"op='comments' AND BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'",
		'GROUP BY op',
		{distinct => 1});
}

########################################################
sub countDaily {
	my($self) = @_;
	my %returnable;

	my $constants = getCurrentStatic();

	($returnable{'total'}) = $self->sqlSelect("count(*)", "accesslog",
		"to_days(now()) - to_days(ts)=1");

	my $c = $self->sqlSelectMany("count(*)", "accesslog",
		"to_days(now()) - to_days(ts)=1 GROUP BY host_addr");
	$returnable{'unique'} = $c->rows;
	$c->finish;

	$c = $self->sqlSelectMany("count(*)", "accesslog",
		"to_days(now()) - to_days(ts)=1 GROUP BY uid");
	$returnable{'unique_users'} = $c->rows;
	$c->finish;

	$returnable{'journals'}  = $self->sqlSelect("count(*)", "accesslog",
		"op='journal' AND to_days(now()) - to_days(ts)=1 GROUP BY op");

	$c = $self->sqlSelectMany("dat,count(*)", "accesslog",
		"to_days(now()) - to_days(ts)=1 AND
		(op='index' OR dat='index')
		GROUP BY dat");

	my(%indexes, %articles, %commentviews);

	while (my($sect, $cnt) = $c->fetchrow) {
		$indexes{$sect} = $cnt;
	}
	$c->finish;

	$c = $self->sqlSelectMany("dat,count(*),op", "accesslog",
		"to_days(now()) - to_days(ts)=1 AND op='article'",
		"GROUP BY dat");

	while (my($sid, $cnt) = $c->fetchrow) {
		$articles{$sid} = $cnt;
	}
	$c->finish;

	$returnable{'index'} = \%indexes;
	$returnable{'articles'} = \%articles;


	return \%returnable;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Stats - Stats system splace

=head1 SYNOPSIS

	use Slash::Stats;

=head1 DESCRIPTION

This is the Slash stats system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
