# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Admin;

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Admin'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getAccesslogMaxID {
	my($self) = @_;
	return $self->sqlSelect("MAX(id)", "accesslog");
}

sub getRecentSubs {
	my($self, $startat) = @_;
	my $slashdb = getCurrentDB();
	my $subs = $slashdb->sqlSelectAllHashrefArray(
		"spid, subscribe_payments.uid,
		 nickname,
		 email, ts, payment_gross, pages,
		 transaction_id, method",
		"subscribe_payments, users",
		"subscribe_payments.uid=users.uid",
		"ORDER BY spid DESC
		 LIMIT $startat, 30");
	return $subs;
}

sub getRecentWebheads {
	my($self, $max_num_mins, $max_num_ids) = @_;
	# Pick reasonable defaults.  max_num_minds is passed directly into an
	# SQL statement so it gets extra syntax checking.
	$max_num_mins ||= 10;
	$max_num_mins   = 10   if $max_num_mins !~ /^\d+$/;
	$max_num_ids ||= 25000;

	my $max_id = $self->getAccesslogMaxID();
	my $min_id = $max_id - $max_num_ids;
	$min_id = 0 if $min_id < 0;

	my $data_hr = $self->sqlSelectAllHashref(
		[qw( minute local_addr )],
		"DATE_FORMAT(ts, '%m-%d %H:%i') AS minute, local_addr, AVG(duration) AS dur, COUNT(*) AS c",
		"accesslog",
		"id >= $min_id AND ts >= DATE_SUB(NOW(), INTERVAL $max_num_mins MINUTE)",
		"GROUP BY minute, local_addr");

	return $data_hr;
}

sub getAccesslogAbusersByID {
	my($self, $options) = @_;
	my $slashdb = $options->{slashdb} || $self;
	my $logdb = $options->{logdb} || $self;
	my $min_id = $options->{min_id} || 0;
	my $max_id = $logdb->sqlSelect('MAX(id)', 'accesslog');
	my $thresh_count = $options->{thresh_count} || 100;
	my $thresh_hps = $options->{thresh_hps} || 0.1;
	my $limit = 500;

	my $ar = $logdb->sqlSelectAllHashrefArray(
		"COUNT(*) AS c, host_addr AS ipid, op,
		 MIN(ts) AS mints, MAX(ts) AS maxts,
		 UNIX_TIMESTAMP(MAX(ts))-UNIX_TIMESTAMP(MIN(ts)) AS secs,
		 COUNT(*)/GREATEST(UNIX_TIMESTAMP(MAX(ts))-UNIX_TIMESTAMP(MIN(ts)),1) AS hps",
		"accesslog",
		"id BETWEEN $min_id AND $max_id",
		"GROUP BY host_addr,op
		 HAVING c >= $thresh_count
			AND hps >= $thresh_hps
		 ORDER BY maxts DESC, c DESC
		 LIMIT $limit"
	);
	return [ ] if !$ar || !@$ar;

	# If we're returning data, find any IPIDs which are already listed
	# as banned and put the reason in too.
	# XXX This feature was taken out because accesslist is gone now;
	# it would be nice to replace this feature with the AL2
	# equivalent - Jamie 2005/07/21
#	my @ipids = map { $self->sqlQuote($_->{ipid}) } @$ar;
#	my $ipids = join(",", @ipids);
#	my $hr = $slashdb->sqlSelectAllHashref(
#		"ipid",
#		"ipid, ts, reason",
#		"accesslist",
#		"ipid IN ($ipids) AND now_ban = 'yes' AND reason != ''"
#	);
#	for my $row (@$ar) {
#		next unless exists $hr->{$row->{ipid}};
#		$row->{bannedts}     = $hr->{$row->{ipid}}{ts};
#		$row->{bannedreason} = $hr->{$row->{ipid}}{reason};
#	}

	return $ar;
}


##################################################################
# Generates the 'Related Links' for Stories
sub getRelated {
	my($self, $story_content, $tid) = @_;

	my $slashdb = getCurrentDB();
	my $user    = getCurrentUser();

	my $rl = $slashdb->getRelatedLinks;
	my @related_text = ( );
	my @rl_keys = sort keys %$rl;

	my @tids = ( $tid );
	if (ref($tid) && ref($tid) eq 'ARRAY') {
		@tids = @$tid;
	}
	my $tid_regex = "^_topic_id_"
		. "(?:"
			. join("|", map { "\Q$_" } @tids)
		. ")"
		. "(?!\\d)";

	if ($rl) {
		my @matchkeys =
			sort grep {
				$rl->{$_}{keyword} =~ $tid_regex
				||
				$rl->{$_}{keyword} !~ /^_topic_id_/
					&& $story_content =~ /\b$rl->{$_}{keyword}\b/i
			} @rl_keys;
		for my $key (@matchkeys) {
			# Instead of hard-coding the HTML here, we should
			# do something a little more flexible.
			my $str = qq[<li><a href="$rl->{$key}{link}">$rl->{$key}{name}</a></li>\n];
			push @related_text, $str;
		}
	}

	# And slurp in all of the anchor links (<A>) from the story just for
	# good measure.  If TITLE attribute is present, use that for the link
	# label; otherwise just use the A content.
	while ($story_content =~ m|<a\s+(.*?)>(.*?)</a>|sgi) {
		my($a_attr, $label) = ($1, $2);
		next unless $a_attr =~ /\bhref\s*=\s*["']/si;
		if ($a_attr =~ m/(\btitle\s*=\s*(["'])(.*?)\2)/si) {
			$label = $3;
			$a_attr =~ s/\Q$1\E//;
		}

		$a_attr =~ /\bhref\s*=\s*(["'])(.*?)\1/;
		my $a_href = $2;
		# If we want to exclude certain types of links from appearing
		# in Related Links, we can make that decision based on the
		# link target here.

		$a_href =~ /(\w\.\w?)$/;
		my $a_href_domain = $1;

		$label = strip_notags($label);
		next if $label !~ /\S/;
		$label =~ s/(\S{30})/$1 /g;
		# Instead of hard-coding the HTML here, we should
		# do something a little more flexible.
		my $str;
		if (submitDomainAllowed($a_href_domain)) {
			$str = qq[<li><a $a_attr>$label</a></li>\n];
		} else {
			$str = qq[<li><blink><b><a style="color: #FF0000;" $a_attr>$label</a></b></blink></li>\n];
		}
		push @related_text, $str unless $label eq "?" || $label eq "[?]";
	}

	for (@{$user->{state}{related_links}}) {
		push @related_text, sprintf(
			# Instead of hard-coding the HTML here, we should
			# do something a little more flexible.
			qq[<li><a href="%s">%s</a></li>\n],
			strip_attribute($_->[1]), $_->[0]
		);
	}

	# Check to make sure we don't include the same link twice.
	my %related_text = ( );
	my $return_str = "";
	for my $rt (@related_text) {
		next if $related_text{$rt};
		$return_str .= $rt;
		$related_text{$rt} = 1;
	}
	return $return_str;
}

##################################################################
sub ajax_signoff {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	return unless $user->{is_admin};
	
	my $stoid = $form->{stoid};
	my $uid   = $user->{uid};

	return unless $stoid =~/^\d+$/;

	if ($slashdb->sqlCount("signoff", "stoid = $stoid AND uid = $uid")) {
		return "Already Signed";
	}
	
	$slashdb->createSignoff($stoid, $uid, "signed");
	return "Signed";
}


##################################################################

sub getStorySignoffs {
	my($self, $stoid) = @_;
	my $stoid_q = $self->sqlQuote($stoid);
	return $self->sqlSelectAllHashrefArray(
		"users.uid, users.nickname, author_story_signoff.signoff_time",
		"author_story_signoff,users", 
		"author_story_signoff.stoid=$stoid_q AND author_story_signoff.uid = users.uid", 
		"ORDER BY signoff_time"
	);
}

##################################################################
sub otherLinks {
	my($self, $aid, $tid, $uid) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $topics = $reader->getTopics;
	my @tids = ( $tid );
	if (ref($tid) && ref($tid) eq 'ARRAY') {
		@tids = @$tid;
	}

	return slashDisplay('otherLinks', {
		uid		=> $uid,
		aid		=> $aid,
		tids		=> \@tids,
		topics		=> $topics,
	}, {
		Return  => 1,
		Nocomm  => 1,
		Page	=> 'admin'
	});
}

##################################################################
sub relatedLinks {
	my($self, $story_content, $tids, $nick, $uid) = @_;
	my $relatedtext = $self->getRelated($story_content, $tids) .
		$self->otherLinks($nick, $tids, $uid);

	# If getRelated and otherLinks seem to be putting <li>
	# tags around each item, they probably want a <ul></ul>
	# surrounding the whole list.  This is a bit hacky but
	# should help make strictly parsed versions of HTML
	# work better.
	$relatedtext = "<ul>\n$relatedtext\n</ul>"
		if $relatedtext && $relatedtext =~ /^\s*<li>/;

	return $relatedtext;
}

sub getSignoffData {
	my ($self, $days) = @_;
	my $days_q = $self->sqlQuote($days);
	my $signoff_info = $self->sqlSelectAllHashrefArray(
		"stories.stoid, users.uid, (unix_timestamp(min(signoff_time)) - unix_timestamp(stories.time)) / 60 AS min_to_sign, users.nickname",
		"stories, story_topics_rendered, signoff, users",
		"stories.stoid = story_topics_rendered.stoid AND signoff.stoid=stories.stoid AND users.uid = signoff.uid
	         AND stories.time <= NOW() AND stories.time > DATE_SUB(NOW(), INTERVAL $days_q DAY)",
		"GROUP BY signoff.uid, signoff.stoid"
	);
	return $signoff_info;

}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__
