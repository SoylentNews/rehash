# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::FireHose;

=head1 NAME

Slash::FireHose - Perl extension for FireHose


=head1 SYNOPSIS

	use Slash::FireHose;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Slashboxes;
use Slash::Tags;
use Data::JavaScript::Anon;
use Date::Calc qw(Days_in_Month Add_Delta_YMD);
use POSIX qw(ceil);
use LWP::UserAgent;
use URI;
use Time::HiRes;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our $VERSION = $Slash::Constants::VERSION;

sub createFireHose {
	my($self, $data) = @_;
	$data->{dept} ||= "";
	$data->{discussion} = 0 if !defined $data->{discussion} || !$data->{discussion};
	$data->{-createtime} = "NOW()" if !$data->{createtime} && !$data->{-createtime};
	$data->{discussion} ||= 0 if defined $data->{discussion};
	$data->{popularity} ||= 0;
	$data->{editorpop} ||= 0;
	$data->{body_length} = $data->{bodytext} ? length($data->{bodytext}) : 0;
	$data->{word_count} = countWords($data->{introtext}) + countWords($data->{bodytext});
	$data->{mediatype} ||= "none";

	my $text_data = {};
	$text_data->{title} = delete $data->{title};
	$text_data->{introtext} = delete $data->{introtext};
	$text_data->{bodytext} = delete $data->{bodytext};
	$text_data->{media} = delete $data->{media};

	$self->sqlDo('SET AUTOCOMMIT=0');
	my $ok = $self->sqlInsert("firehose", $data);
	if (!$ok) {
		warn "could not create firehose row, '$ok'";
	}
	if ($ok) {
		$text_data->{id} = $self->getLastInsertId({ table => 'firehose', prime => 'id' });

		my $searchtoo = getObject('Slash::SearchToo');
		if ($searchtoo) {
			$searchtoo->storeRecords(firehose => $text_data->{id}, { add => 1 });
		}

		$ok = $self->sqlInsert("firehose_text", $text_data);
		if (!$ok) {
			warn "could not create firehose_text row for id '$text_data->{id}'";
		}
	}

	if ($ok) {
		$self->sqlDo('COMMIT');
	} else {
		$self->sqlDo('ROLLBACK');
	}
	$self->sqlDo('SET AUTOCOMMIT=1');

	return $text_data->{id};
}

sub createUpdateItemFromJournal {
	my($self, $id) = @_;
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $globjid_q = $self->sqlQuote($globjid);
		# XXX does this next line depend on the primary key being the
		# first column returned by "SELECT *"? If I read that right,
		# that's non-intuitive; we should select id by name instead. -Jamie
		my($itemid) = $self->sqlSelect("*", "firehose", "globjid=$globjid_q");
		if ($itemid) {
			my $introtext = balanceTags(strip_mode($journal->{article}, $journal->{posttype}), { deep_nesting => 1 });
			$self->setFireHose($itemid, { 
				introtext => $introtext, 
				title => $journal->{description}, 
				tid => $journal->{tid}, 
				discussion => $journal->{discussion}, 
				word_count => countWords($introtext) 
			});

		} else {
			$self->createItemFromJournal($id);
		}
	}
}

sub getFireHoseColors {
	my($self, $array) = @_;
	my $constants = getCurrentStatic();
	my $color_str = $constants->{firehose_color_labels};
	my @colors = split(/\|/, $color_str);
	return \@colors if $array;
	my $colors = {};
	my $i=1;
	foreach (@colors) {
		$colors->{$_} = $i++;
	}
	return $colors;
}



sub createItemFromJournal {
	my($self, $id) = @_;
	my $user = getCurrentUser();
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	my $introtext = balanceTags(strip_mode($journal->{article}, $journal->{posttype}), { deep_nesting => 1 });
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $publicize = $journal->{promotetype} eq 'publicize';
		my $color_lvl = $publicize ? 5 : 6;
		my $popularity = $self->getEntryPopularityForColorLevel($color_lvl);
		my $type = $user->{acl}{vendor} ? "vendor" : "journal";
		my $data = {
			title 			=> $journal->{description},
			globjid 		=> $globjid,
			uid 			=> $journal->{uid},
			attention_needed 	=> "yes",
			public 			=> "yes",
			introtext 		=> $introtext,
			popularity		=> $popularity,
			editorpop		=> $popularity,
			tid			=> $journal->{tid},
			srcid			=> $id,
			discussion		=> $journal->{discussion},
			type			=> $type,
			ipid			=> $user->{ipid},
			subnetid		=> $user->{subnetid},
		};
		$self->createFireHose($data);
		if ($publicize && !isAnon($journal->{uid})) {
			my $constants = getCurrentStatic();
			my $tags = getObject('Slash::Tags');
			$tags->createTag({
				uid		=> $journal->{uid},
				name		=> $constants->{tags_upvote_tagname},
				globjid		=> $globjid,
				private		=> 1,
			});
		}
	}

}

sub createUpdateItemFromBookmark {
	my($self, $id, $options) = @_;
	$options ||= {};
	my $constants = getCurrentStatic();
	my $bookmark_db = getObject("Slash::Bookmark");
	my $bookmark = $bookmark_db->getBookmark($id);
	my $url_globjid = $self->getGlobjidCreate("urls", $bookmark->{url_id});
	my $type = $options->{type} || "bookmark";
	my($count) = $self->sqlCount("firehose", "globjid=$url_globjid");
	my $popularity = defined $options->{popularity}
		? $options->{popularity}
		: $type eq "feed"
			? $self->getEntryPopularityForColorLevel(6)
			: $self->getEntryPopularityForColorLevel(7);
	my $activity   = defined $options->{activity} ? $options->{activity} : 1;

	if ($count) {
		# $self->sqlUpdate("firehose", { -popularity => "popularity + 1" }, "globjid=$url_globjid");
	} else {

		my $data = {
			globjid 	=> $url_globjid,
			title 		=> $bookmark->{title},
			url_id 		=> $bookmark->{url_id},
			uid 		=> $bookmark->{uid},
			popularity 	=> $popularity,
			editorpop	=> $popularity,
			activity 	=> $activity,
			public 		=> "yes",
			type		=> $type,
			srcid		=> $id
		};
		$data->{introtext} = $options->{introtext} if $options->{introtext};
		if ($type eq "feed") {
			my $feed = $bookmark_db->getBookmarkFeedByUid($bookmark->{uid});	
			if ($feed && $feed->{feedname}) {
				$data->{srcname} = $feed->{feedname};	
			}
		}
		my $firehose_id = $self->createFireHose($data);
		if ($firehose_id && $type eq "feed") {
			my $discussion_id = $self->createDiscussion({
				uid		=> 0,
				kind		=> 'feed',
				title		=> $bookmark->{title},
				commentstatus	=> 'logged_in',
				url		=> "$constants->{rootdir}/firehose.pl?op=view&id=$firehose_id"
			});
			if ($discussion_id) {
				$self->setFireHose($firehose_id, {
					discussion	=> $discussion_id,
				});
			}
			
		}		

		if (!isAnon($bookmark->{uid})) {
			my $constants = getCurrentStatic();
			my $tags = getObject('Slash::Tags');
			$tags->createTag({
				uid			=> $bookmark->{uid},
				name			=> $constants->{tags_upvote_tagname},
				globjid			=> $url_globjid,
				private			=> 1,
			});
		}
	}
}

sub createItemFromSubmission {
	my($self, $id) = @_;
	my $submission = $self->getSubmission($id, "", 1);
	if ($submission) {
		my $globjid = $self->getGlobjidCreate("submissions", $submission->{subid});
		my $midpop = $self->getEntryPopularityForColorLevel(5);
		my $data = {
			title 			=> $submission->{subj},
			globjid 		=> $globjid,
			uid 			=> $submission->{uid},
			introtext 		=> $submission->{story},
			popularity 		=> $midpop,
			editorpop 		=> $midpop,
			public 			=> "yes",
			attention_needed 	=> "yes",
			type 			=> "submission",
			primaryskid		=> $submission->{primaryskid},
			tid 			=> $submission->{tid},
			srcid 			=> $id,
			ipid 			=> $submission->{ipid},
			subnetid 		=> $submission->{subnetid},
			email			=> $submission->{email},
			emaildomain		=> $submission->{emaildomain},
			name			=> $submission->{name},
			mediatype		=> $submission->{mediatype}
		};
		$data->{url_id} = $submission->{url_id} if $submission->{url_id};
		my $firehose_id = $self->createFireHose($data);
		if (!isAnon($submission->{uid})) {
			my $constants = getCurrentStatic();
			my $tags = getObject('Slash::Tags');
			$tags->createTag({
				uid			=> $submission->{uid},
				name			=> $constants->{tags_upvote_tagname},
				globjid			=> $globjid,
				private			=> 1,
			});
		}
		return $firehose_id;
	}

}

sub updateItemFromStory {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	my %ignore_skids = map {$_ => 1 } @{$constants->{firehose_story_ignore_skids}};
	my $story = $self->getStory($id, "", 1);
	if ($story) {
		my $globjid = $self->getGlobjidCreate("stories", $story->{stoid});
		my $id = $self->getFireHoseIdFromGlobjid($globjid);
		if ($id) {
			# If a story is getting its primary skid to an ignored value set its firehose entry to non-public
			my $public = ($story->{neverdisplay} || $ignore_skids{$story->{primaryskid}}) ? "no" : "yes";
			my $data = {
				title 		=> $story->{title},
				uid		=> $story->{uid},
				createtime	=> $story->{time},
				introtext	=> parseSlashizedLinks($story->{introtext}),
				bodytext	=> parseSlashizedLinks($story->{bodytext}),
				media		=> $story->{media},
				primaryskid	=> $story->{primaryskid},
				tid 		=> $story->{tid},
				public		=> $public,
				dept		=> $story->{dept},
				discussion	=> $story->{discussion},
				body_length	=> $story->{body_length},
				word_count	=> $story->{word_count},
				thumb		=> $story->{thumb},
				
			};
			$self->setFireHose($id, $data);
		}
	}
}

sub createItemFromStory {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	# If a story is created with an ignored primary skid it'll never be created as a firehose entry currently
	my %ignore_skids = map {$_ => 1 } @{$constants->{firehose_story_ignore_skids}};
	my $story = $self->getStory($id, '', 1);

	my $popularity = $self->getEntryPopularityForColorLevel(2);
	if ($story->{story_topics_rendered}{$constants->{mainpage_nexus_tid}}) {
		$popularity = $self->getEntryPopularityForColorLevel(1);
	}

	if ($story && !$ignore_skids{$story->{primaryskid}}) {
		my $globjid = $self->getGlobjidCreate("stories", $story->{stoid});
		my $public = $story->{neverdisplay} ? "no" : "yes";
		my $data = {
			title 		=> $story->{title},
			globjid 	=> $globjid,
			uid		=> $story->{uid},
			createtime	=> $story->{time},
			introtext	=> parseSlashizedLinks($story->{introtext}),
			bodytext	=> parseSlashizedLinks($story->{bodytext}),
			media		=> $story->{media},
			popularity	=> $popularity,
			editorpop	=> $popularity,
			primaryskid	=> $story->{primaryskid},
			tid 		=> $story->{tid},
			srcid		=> $id,
			type 		=> "story",
			public		=> $public,
			dept		=> $story->{dept},
			discussion	=> $story->{discussion},
			thumb		=> $story->{thumb},
		};
		$self->createFireHose($data);
	}
}

sub getFireHoseCount {
	my($self) = @_;
	my $pop = $self->getEntryPopularityForColorLevel(6);
	my $user = getCurrentUser();
	my $pop_q = $self->sqlQuote($pop);
	my $signoff_label = "sign$user->{uid}\ed";

	#XXXFH - add time limit later?
	return $self->sqlCount("firehose", "editorpop >= $pop_q and rejected='no' and accepted='no' and type!='story'");
}

sub getFireHoseEssentials {
	my($self, $options) = @_;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $colors = $self->getFireHoseColors();

	$options ||= {};
	$options->{limit} ||= 50;
	my $ps = $options->{limit};

	my $fetch_extra = 0;
	my($day_num, $day_label, $day_count);

	$options->{limit} += $options->{more_num} if $options->{more_num};

	my $fetch_size = $options->{limit};
	if ($options->{orderby} eq "createtime") {
		$fetch_extra = 1;
		$fetch_size++;
	}

	my $pop;
	$pop = $self->getMinPopularityForColorLevel($colors->{$options->{color}})
		if $options->{color} && $colors->{$options->{color}};

	my($items, $results, $doublecheck) = ([], {}, 0);
	# for now, only bother to try searchtoo if there is a qfilter value to search on
	if (!$options->{no_search} && $constants->{firehose_searchtoo} && $options->{qfilter}) {
		my $searchtoo = getObject('Slash::SearchToo');
		if ($searchtoo && $searchtoo->handled('firehose')) {
			my(%opts, %query);
			$query{query}		= $options->{qfilter}			if defined $options->{qfilter};
			$query{category}	= $options->{category} || 'none'	if $options->{category} || $user->{is_admin};
			if ($options->{ids}) {
				if (ref($options->{ids}) eq 'ARRAY' && @{$options->{ids}} < 1) {
					return([], {});
				}
				$query{id}		= $options->{ids}		if $options->{ids};
			}

			# attention_needed not indexed right now
			for (qw(attention_needed public accepted rejected type primaryskid uid)) {
				$query{$_}	= $options->{$_}		if $options->{$_};
			}

			if ($options->{startdate}) {
				$opts{daystart} = $options->{startdate};
			}
			if ($options->{duration} && $options->{duration} >= 0) {
				$opts{dayduration} = $options->{duration};
			}

			$opts{records_max}	= $fetch_size             unless $options->{nolimit};
			$opts{records_start}	= $options->{offset}      if $options->{offset};
			$opts{sort}		= 3;  # sorting handled by caller

			# just a few options to carry over
			$opts{carryover} = {
				map { ($_ => $options->{$_}) } qw(tagged_by_uid orderdir orderby ignore_nix tagged_positive tagged_negative tagged_non_negative unsigned signed)
			};

			$results = $searchtoo->findRecords(firehose => \%query, \%opts);
			$items = delete $results->{records};

			return($items, $results) if ! @$items;

			$options->{ids} = [ map { $_->{id} } @$items ];
			$doublecheck = 1;
		}
	}

	# sometimes we just pass options to searchtoo and get them back later
	if ($options->{carryover}) {
		my $co = $options->{carryover};
		@{$options}{keys %$co} = values %$co;
		delete $options->{carryover};
	}

#use Data::Dumper; print STDERR Dumper $options;

	$options->{orderby} ||= 'createtime';
	$options->{orderdir} = uc($options->{orderdir}) eq 'ASC' ? 'ASC' : 'DESC';
	#($user->{is_admin} && $options->{orderby} eq 'createtime' ? 'ASC' :'DESC');

	my @where;
	my $tables = 'firehose';
	my $filter_globjids;
	if ($options->{tagged_by_uid} && (!$doublecheck || $options->{ignore_nix})) {
		my $tag_by_uid_q = $self->sqlQuote($options->{tagged_by_uid});
		$tables .= ', tags';
		push @where, 'tags.globjid=firehose.globjid';
		push @where, "tags.uid = $tag_by_uid_q";

		if ($options->{ignore_nix}) {
			my $downlabel = $constants->{tags_downvote_tagname} || 'nix';
			my $tags = getObject('Slash::Tags');
			my $nix_id = $tags->getTagnameidFromNameIfExists($downlabel);
			push @where, "tags.tagnameid != $nix_id";
		} elsif ($options->{tagged_positive} || $options->{tagged_negative} || $options->{tagged_non_negative}) {
			my $labels;
			my $not = '';
			my $tags = getObject('Slash::Tags');

			if ($options->{tagged_positive}) {
				$labels = $tags->getPositiveTags;
				$labels = ['nod'] unless @$labels;
			} else { # tagged_non_negative || tagged_negative
				$labels = $tags->getNegativeTags;
				$labels = ['nix'] unless @$labels;
				$not = 'NOT' if $options->{tagged_non_negative};
			}

			my $ids = join ',', grep $_, map {
				s/\s+//g;
				$tags->getTagnameidFromNameIfExists($_)
			} @$labels;
			push @where, "tags.tagnameid $not IN ($ids)";

			if ($not) {
				$filter_globjids = $self->sqlSelectAllHashref(
					'globjid', 'DISTINCT globjid', 'tags',
					"uid = $tag_by_uid_q AND tagnameid IN ($ids)"
				);
			}
		}
	}
	my $columns = "firehose.*, firehose.popularity AS userpop";

		if ($options->{createtime_no_future}) {
			push @where, 'createtime <= NOW()';
		}

		if ($options->{createtime_subscriber_future}) {
			my $future_secs = $constants->{subscribe_future_secs};
			push @where, "createtime <= DATE_ADD(NOW(), INTERVAL $future_secs SECOND)";
		}

	if (!$doublecheck) {

		if ($options->{public}) {
			push @where, 'public = ' . $self->sqlQuote($options->{public});
		}

		if (($options->{filter} || $options->{fetch_text}) && !$doublecheck) {
			$tables .= ',firehose_text';
			push @where, 'firehose.id = firehose_text.id';

			if ($options->{filter}) {
				# sanitize $options->{filter};
				$options->{filter} =~ s/[^a-zA-Z0-9_]+//g;
				push @where, "firehose_text.title LIKE '%$options->{filter}%'";
			}

			if ($options->{fetch_text}) {
				$columns .= ',firehose_text.*';
			}
		}

		my $dur_q = $self->sqlQuote($options->{duration});
		my $st_q  = $self->sqlQuote(timeCalc($options->{startdate}, '%Y-%m-%d %T', -$user->{off_set}));

		if ($options->{startdate}) {

			if ($options->{duration} && $options->{duration} >= 0 ) {
				push @where, "createtime >= $st_q";
				push @where, "createtime <= DATE_ADD($st_q, INTERVAL $dur_q DAY)";
			} elsif ($options->{duration} == -1) {
				if ($options->{orderdir} eq "ASC") {
					push @where, "createtime >= $st_q";
				} else {
					my $end_q = $self->sqlQuote(timeCalc("$options->{startdate} 23:59:59", '%Y-%m-%d %T', -$user->{off_set}));				   push @where, "createtime <= $end_q";
				}
			}
		} elsif (defined $options->{duration} && $options->{duration} >= 0) {
			push @where, "createtime >= DATE_SUB(NOW(), INTERVAL $dur_q DAY)";
		}

		foreach my $prefix ("","not_") {
			foreach my $base qw(primaryskid uid type) {
				if ($options->{"$prefix$base"}) {
					my $not = $prefix eq "not_" ? 1 : 0;
					my $cur_opt = $options->{"$prefix$base"};
					$cur_opt = [$cur_opt] if !ref $cur_opt;
					my $notlab;
					if (@$cur_opt == 1) {
					     $notlab = $not ? "!" : "";
					     my $quoted_opt = $self->sqlQuote($cur_opt->[0]);
					     push @where, "$base $notlab=$quoted_opt";
					} elsif (@$cur_opt > 1) {
					     $notlab = $not ? "NOT" : "";

					     my $quote_string = join ',', map {$self->sqlQuote($_)} @$cur_opt;
					     push @where, "$base $notlab IN  ($quote_string)";
					}

				}
			}
		}

	}

		if ($pop) {
			my $pop_q = $self->sqlQuote($pop);
			if ($user->{is_admin} && !$user->{firehose_usermode}) {
				push @where, "editorpop >= $pop_q";
			} else {
				push @where, "popularity >= $pop_q";
			}
		}
		if ($user->{is_admin} || $user->{acl}{signoff_allowed}) {
			my $signoff_label = 'sign' . $user->{uid} . 'ed';

			if ($options->{unsigned}) {
				push @where, "signoffs NOT LIKE '%$signoff_label%'";
			} elsif ($options->{signed}) {
				push @where, "signoffs LIKE '%$signoff_label%'";
			}
		}

	# check these again, just in case, as they are more time-sensitive
	# and don't take much effort to check
	if ($options->{attention_needed}) {
		push @where, 'attention_needed = ' . $self->sqlQuote($options->{attention_needed});
	}

	if ($options->{accepted}) {
		push @where, 'accepted = ' . $self->sqlQuote($options->{accepted});
	}

	if ($options->{rejected}) {
		push @where, 'rejected = ' . $self->sqlQuote($options->{rejected});
	}

	if (defined $options->{category} || $user->{is_admin}) {
		$options->{category} ||= '';
		push @where, 'category = ' . $self->sqlQuote($options->{category});
	}

	if ($options->{ids}) {
		return($items, $results) if @{$options->{ids}} < 1;
		my $id_str = join ',', map { $self->sqlQuote($_) } @{$options->{ids}};
		push @where, "firehose.id IN ($id_str)";
	}

	if ($options->{not_id}) {
		push @where, "firehose.id != " . $self->sqlQuote($options->{not_id});
	}

	my $limit_str = '';
	my $where = (join ' AND ', @where) || '';

	my $other = '';
	$other = 'GROUP BY firehose.id' if $options->{tagged_by_uid};

	my $count_other = $other;
	my $offset;

	if (1 || !$doublecheck) { # do always for now
		$offset = defined $options->{offset} ? $options->{offset} : '';
		$offset = '' if $offset !~ /^\d+$/;
		$offset = "$offset, " if length $offset;
		$limit_str = "LIMIT $offset $fetch_size" unless $options->{nolimit};
		$other .= " ORDER BY $options->{orderby} $options->{orderdir} $limit_str";
	}


#print STDERR "[\nSELECT $columns\nFROM   $tables\nWHERE  $where\n$other\n]\n";
	my $hr_ar = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other);

	if ($fetch_extra && @$hr_ar == $fetch_size) {
		$fetch_extra = pop @$hr_ar;
		($day_num, $day_label, $day_count) = $self->getNextDayAndCount(
			$fetch_extra, $options, $tables, \@where, $count_other
		);
	}

	my $count;
	if ($options->{tagged_by_uid}) {
		my $rows = $self->sqlSelectAllHashrefArray("count(*)", $tables, $where, $count_other);
		$count = @$rows;
	} else {
		$count = $self->sqlSelect("count(*)", $tables, $where, $count_other);
	}


	my $page_size = $ps || 1;
	$results->{records_pages} ||= ceil($count / $page_size);
	$results->{records_page}  ||= (int(($options->{offset} || 0) / $options->{limit}) + 1) || 1;

	my $future_count = $count - $options->{limit} - ($options->{offset} || 0);

	if (keys %$filter_globjids) {
		for my $i (0 .. $#{$hr_ar}) {
			my $el = $hr_ar->[$i] or last;
			if (exists($filter_globjids->{ $el->{globjid} })) {
				splice(@$hr_ar, $i, 1);
				$i--;
			}
		}
	}

	# make sure these items (from SearchToo) still match -- pudge
	if ($doublecheck) {
		my %hrs = map { ( $_->{id}, 1 ) } @$hr_ar;
		my @tmp_items;
		for my $item (@$items) {
			push @tmp_items, $item if $hrs{$item->{id}};
		}
		$items = \@tmp_items;

	# Add globj admin notes to the firehouse hashrefs.
	} else {
		my $globjids = [ map { $_->{globjid} } @$hr_ar ];
		my $note_hr = $self->getGlobjAdminnotes($globjids);
		for my $hr (@$hr_ar) {
			$hr->{note} = $note_hr->{ $hr->{globjid} } || '';
		}

		$items = $hr_ar;
	}
	return($items, $results, $count, $future_count, $day_num, $day_label, $day_count);
}

sub getNextDayAndCount {
	my($self, $item, $opts, $tables, $where_ar, $other) = @_;

	my $user = getCurrentUser();

	my $item_day = timeCalc($item->{createtime}, '%Y-%m-%d');

	my $is_desc = $opts->{orderdir} eq "DESC";

	my $border_time = $is_desc ? "$item_day 00:00:00" : "$item_day 23:59:59";
	$border_time = timeCalc($border_time, "%Y-%m-%d %T", -$user->{off_set});

	my $it_cmp =  $is_desc ? "<=" : ">=";
	my $bt_cmp =  $is_desc ? ">=" : "<=";

	my $i_time_q 	  = $self->sqlQuote($item->{createtime});
	my $border_time_q = $self->sqlQuote($border_time);

	my $where = join ' AND ', @$where_ar, "createtime $it_cmp $i_time_q", "createtime $bt_cmp $border_time_q";

	my $day_count = $self->sqlSelect("count(*)", $tables, $where, $other);
	
	my $day_labels = getOlderDaysFromDay($item_day, 0, 0, { skip_add_today => 1, show_future_days => 1, force => 1 });

	return($day_labels->[0]->[0], $day_labels->[0]->[1], $day_count);
}

# A single-globjid wrapper around getUserFireHoseVotesForGlobjs.

sub getUserFireHoseVoteForGlobjid {
	my($self, $uid, $globjid) = @_;
	my $vote_hr = $self->getUserFireHoseVotesForGlobjs($uid, [ $globjid ]);
	return $vote_hr->{$globjid};
}

# This isn't super important but I'd prefer the method name to
# be getUserFireHoseVotesForGlobjids.  We spelled out "Globjid"
# in the methods getTagsByGlobjid and getFireHoseIdFromGlobjid.
# Not worth changing right now - Jamie 2008-01-09

sub getUserFireHoseVotesForGlobjs {
	my($self, $uid, $globjs) = @_;
	my $constants = getCurrentStatic();

	return {} if !$globjs;
	$globjs = [$globjs] if !ref $globjs;
	return {} if @$globjs < 1;
	my $uid_q = $self->sqlQuote($uid);
	my $glob_str = join ",", map { $self->sqlQuote($_) } @$globjs;
	
	my $upvote   = $constants->{tags_upvote_tagname}   || 'nod';
	my $downvote = $constants->{tags_downvote_tagname} || 'nix';

	my $tags = getObject("Slash::Tags", { db_type => "reader" });
	my $upid = $tags->getTagnameidCreate($upvote);
	my $dnid = $tags->getTagnameidCreate($downvote);

	my $results = $self->sqlSelectAllKeyValue(
		"globjid,tagnameid",
		"tags", 
		"globjid IN ($glob_str) AND inactivated IS NULL
		 AND uid = $uid_q AND tagnameid IN ($upid,$dnid)"
	);

	foreach (keys %$results) {
		$results->{$_} = "up" if $results->{$_} == $upid;
		$results->{$_} = "down" if $results->{$_} == $dnid;
	}
	
	return $results;
}

sub getFireHoseByTypeSrcid {
	my($self, $type, $id) = @_;
	my $type_q = $self->sqlQuote($type);
	my $id_q   = $self->sqlQuote($id);
	my $item = {};
	my $fid = $self->sqlSelect("id", "firehose", "srcid=$id_q and type=$type_q");
	$item = $self->getFireHose($fid) if $fid;
	return $item;
}

sub getFireHose {
	my($self, $id) = @_;

	my $mcd = $self->getMCD();
	my $mcdkey;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:firehose";
		my $item = $mcd->get("$mcdkey:$id");
		return $item if $item;
	}

	# XXX cache this eventually
	my $constants = getCurrentStatic();
	my $id_q = $self->sqlQuote($id);
	my $answer = $self->sqlSelectHashref(
		"*, firehose.popularity AS userpop, UNIX_TIMESTAMP(firehose.createtime) AS createtime_ut",
		"firehose", "id=$id_q");
	my $append = $self->sqlSelectHashref("*", "firehose_text", "id=$id_q");

	for my $key (keys %$append) {
		$answer->{$key} = $append->{$key};
	}

	# globj adminnotes are never the empty string, they are undef
	# instead.  Firehose notes are/were designed to never be undef,
	# the empty string instead.
	$answer->{note} = $self->getGlobjAdminnote($answer->{globjid}) || '';
	
	if ($mcd && $answer->{title}) {
		my $exptime = $constants->{firehose_memcached_exptime} || 600;
		$mcd->set("$mcdkey:$id", $answer, $exptime);
	}

	return $answer;
}

sub getFireHoseIdFromGlobjid {
	my($self, $globjid) = @_;
	my $globjid_q = $self->sqlQuote($globjid);
	return $self->sqlSelect("id", "firehose", "globjid=$globjid_q");
}

sub getFireHoseIdFromUrl {
	my($self, $url) = @_;
	if ($url) {
		my $fudgedurl = fudgeurl($url);
		if ($fudgedurl) {
			my $url_id = $self->getUrlIfExists($fudgedurl);
			if ($url_id) {
				return $self->getPrimaryFireHoseItemByUrl($url_id);
			}
		}
	}
	return 0;
}

sub allowSubmitForUrl {
	my($self, $url_id) = @_;
	my $user = getCurrentUser();
	my $url_id_q = $self->sqlQuote($url_id);

	if ($user->{is_anon}) {
		return !$self->sqlCount("firehose", "url_id=$url_id_q");
	} else {
		my $uid_q = $self->sqlQuote($user->{uid});
		return !$self->sqlCount("firehose", "url_id=$url_id_q AND uid != $uid_q");
	}
}

sub getURLsForItem {
	my($self, $item) = @_;
	my $url_id = $item->{url_id};
	my $url = $url_id ? $self->getUrl($url_id) : undef;
	$url = $url->{url} if $url;
	my $url_prepend = $url ? qq{<a href="$url">$url</a>}   : '';
	my $intro = $item->{introtext} || '';
	my $body = $item->{bodytext} || '';
	my $text = "$url_prepend $intro $body";

	my %urls = ( );
	my $tokens = HTML::TokeParser->new(\$text);
	return ( ) unless $tokens;
	while (my $token = $tokens->get_tag('a')) {
		my $linkurl = $token->[1]{href};
		next unless $linkurl;
		my $canon = URI->new($linkurl)->canonical()->as_string();
		$urls{$canon} = 1;
	}
	return sort keys %urls;
}

sub itemHasSpamURL {
	my($self, $item) = @_;
	my @spamurlregexes = grep { $_ } split /\s+/, ($self->getBlock('spamurlregexes', 'block') || '');
	return 0 unless @spamurlregexes;
	my @urls = $self->getURLsForItem($item);
	for my $url (@urls) {
		for my $regex (@spamurlregexes) {
			return 1 if $url =~ $regex;
		}
	}
	return 0;
}

sub getPrimaryFireHoseItemByUrl {
	my($self, $url_id) = @_;
	my $ret_val = 0;
	if ($url_id) {
		my $url_id_q = $self->sqlQuote($url_id);
		my $count = $self->sqlCount("firehose", "url_id=$url_id_q");
		if ($count > 0) {
			my($uid, $id) = $self->sqlSelect("uid,id",
				"firehose", "url_id = $url_id_q", "ORDER BY id ASC");
			if (isAnon($uid)) {
				$ret_val = $id;
			} else {
				# Logged in, give precedence to most recent submission
				my $uid_q = $self->sqlQuote($uid);
				my($submitted_id) = $self->sqlSelect("id",
					"firehose", "url_id = $url_id_q AND uid=$uid_q", "ORDER BY id DESC");
				$ret_val = $submitted_id ? $submitted_id : $id;
			}
		}
	}
	return $ret_val;
}

sub ajaxFetchMedia {
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $firehose = getObject("Slash::FireHose");
	my $id = $form->{id};
	return unless $id && $firehose;
	my $item = $firehose->getFireHose($id);
	return $item->{media};
}

sub fetchItemText {
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $firehose = getObject("Slash::FireHose");
	my $id = $form->{id};
	return unless $id && $firehose;
	my $item = $firehose->getFireHose($id);
	my $add_secs = 0;
	if ($user->{is_subscriber} && $constants->{subscribe_future_secs}) {
		$add_secs = $constants->{subscribe_future_secs};
	}
	my $cutoff_time = $firehose->getTime({ add_secs => $add_secs });

	return if $item->{public} eq "no" && !$user->{is_admin};
	return if $item->{createtime} ge $cutoff_time && !$user->{is_admin};

	my $tags_top = $firehose->getFireHoseTagsTop($item);

	if ($user->{is_admin}) {
		$firehose->setFireHoseSession($item->{id});
	}
	my $data = {
		item		=> $item,
		mode		=> "bodycontent",
		tags_top	=> $tags_top,
	};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	if (!$user->{is_anon} && $plugins->{Tags}) {
		my $tagsdb = getObject('Slash::Tags');
		$tagsdb->markViewed($user->{uid}, $item->{globjid});
	}

	my $retval = slashDisplay("dispFireHose", $data, { Return => 1, Page => "firehose" });
	return $retval;
}

sub rejectItemBySubid {
	my($self, $subid) = @_;
	if (!ref $subid) {
		$subid = [$subid];
	}
	return unless ref $subid eq "ARRAY";
	my $str;
	if (@$subid > 0) {
		$str = join ',', map { $self->sqlQuote($_) }  @$subid;
		my $ids = $self->sqlSelectColArrayref("id", "firehose", "type='submission' AND srcid IN ($str)");
		foreach (@$ids) {
			$self->setFireHose($_, { rejected => 'yes' });
		}
	}
}

sub rejectItem {
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $firehose = getObject("Slash::FireHose");
	my $id = $form->{id};
	my $id_q = $firehose->sqlQuote($id);
	return unless $id && $firehose;
	$firehose->reject($id);
}

sub reject {
	my ($self, $id) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $tags = getObject("Slash::Tags");
	my $item = $self->getFireHose($id);
	return unless $id;
	if ($item) {
		$self->setFireHose($id, { rejected => "yes" });
		if ($item->{globjid} && !isAnon($user->{uid})) {
			my $downvote = $constants->{tags_downvote_tagname} || 'nix';
			$tags->createTag({
				uid	=>	$user->{uid},
				name	=> 	$downvote,
				globjid	=>	$item->{globjid},
				private	=> 	1
			});
		}
		
		if ($item->{type} eq "submission") {
			if ($item->{srcid}) {
				my $n_q = $self->sqlQuote($item->{srcid});
				my $uid = $user->{uid};
				my $rows = $self->sqlUpdate('submissions',
					{ del => 1 }, "subid=$n_q AND del=0"
				);
				if ($rows) {
					$self->setUser($uid,
						{ -deletedsubmissions => 'deletedsubmissions+1' }
					);
				}
			}
		}
	}
}

sub ajaxSaveOneTopTagFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $tags = getObject("Slash::Tags");
	my $id = $form->{id};
	my $tag = $form->{tags};
	my $firehose = getObject("Slash::FireHose");
	my $item = $firehose->getFireHose($id);
	if ($item) {
		$firehose->setSectionTopicsFromTagstring($id, $tag);
		my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});
		my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $itemid, { uid => $user->{uid}});
		my @tags = sort Slash::Tags::tagnameorder map { $_->{tagname} } @$now_tags_ar;
		push @tags, $tag;
		my $tagsstring = join ' ', @tags;
		my $newtagspreloadtext = $tags->setTagsForGlobj($itemid, $table, $tagsstring);
	}
}

sub ajaxRemoveUserTab {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	return if $user->{is_anon};
	if ($form->{tabid}) {
		my $tabid_q = $slashdb->sqlQuote($form->{tabid});
		my $uid_q   = $slashdb->sqlQuote($user->{uid});
		$slashdb->sqlDelete("firehose_tab", "tabid=$tabid_q AND uid=$uid_q");
	}
	my $firehose = getObject("Slash::FireHose");
	my $opts = $firehose->getAndSetOptions();
	my $html = {};
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs}, options => $opts, section => $form->{section} }, { Return => 1});

	return Data::JavaScript::Anon->anon_dump({
		html	=> $html
	});
}


sub genSetOptionsReturn {
	my($slashdb, $constants, $user, $form, $options, $opts) = @_;
	my $data = {};
	$data->{html}->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs}, options => $opts, section => $form->{section}  }, { Return => 1});
	$data->{html}->{fhoptions} = slashDisplay("firehose_options", { nowrapper => 1, options => $opts }, { Return => 1});
	$data->{html}->{fhadvprefpane} = slashDisplay("fhadvprefpane", { options => $opts }, { Return => 1});

	$data->{values}->{'firehose-filter'} = $opts->{fhfilter};
	if ($form->{tab} || $form->{tabtype}) {
		$data->{eval_last} = "firehose_slider_set_color('$opts->{color}')";
	}

	my $eval_first = "";
	for my $o (qw(startdate mode fhfilter orderdir orderby startdate duration color more_num)) {
		my $value = $opts->{$o};
		if ($o eq 'orderby' && $value eq 'editorpop') {
			$value = 'popularity';
		}
		if ($o eq 'startdate') {
			$value =~ s/-//g;
		}
		if ($o eq 'more_num') {
			$value ||= 0;
		}
		$data->{eval_first} .= "firehose_settings.$o = " . Data::JavaScript::Anon->anon_dump("$value") . "; ";
	}
	return $data;
}

sub ajaxFireHoseSetOptions {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $opts = $firehose->getAndSetOptions();

	$firehose->createSettingLog({
		uid => $user->{uid},
		name => $form->{setting_name},
		value => $form->{$form->{setting_name}},
		"-ts" => "NOW()"}
	);

	my $data = genSetOptionsReturn($slashdb, $constants, $user, $form, $options, $opts);
	return Data::JavaScript::Anon->anon_dump($data);
}

sub ajaxSaveNoteFirehose {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};
	my $note = $form->{note};
	if ($note && $id) {
		my $firehose = getObject("Slash::FireHose");
		$firehose->setFireHose($id, { note => $note });
	}
	return $note || "Note";
}

sub ajaxSaveFirehoseTab {
	my($slashdb, $constants, $user, $form) = @_;
	return if $user->{is_anon};
	my $firehose = getObject("Slash::FireHose");

	my $max_named_tabs = $constants->{firehose_max_tabs} || 10;

	my $tabid = $form->{tabid};
	my $tabname = $form->{tabname};
	$tabname =~ s/^\s+|\s+$//g;
	my $message = "";

	my $user_tabs = $firehose->getUserTabs();
	my %other_tabnames = map { lc($_->{tabname}) => $_->{tabid} } grep { $_->{tabid} != $tabid } @$user_tabs;
	my $original_name = "";
	foreach (@$user_tabs) {
		$original_name = $_->{tabname} if $tabid == $_->{tabid};
	}
	if ($tabname && $tabid) {
		if (length($tabname) == 0 || length($tabname) > 16) {
			$message .= "You specified a tabname that was either too long or too short\n";
		} elsif ($tabname =~/^untitled$/) {
			$message .= "Can't rename a tab to untitled, that name is reserved<br>";
		} elsif ($tabname =~ /[^A-Za-z0-9_-]/) {
			$message .= "You attempted to use unallowed characters in your tab name, stick to alpha numerics<br>";
		} elsif ($original_name eq "untitled" && @$user_tabs >= $max_named_tabs) {
			$message .= "You have too many named tabs, you need to delete one before you can save another";
		} else {
			my $uid_q = $slashdb->sqlQuote($user->{uid});
			my $tabid_q = $slashdb->sqlQuote($tabid);
			my $tabname_q = $slashdb->sqlQuote($tabname);
		
			$slashdb->sqlDelete("firehose_tab", "uid=$uid_q and tabname=$tabname_q and tabid!=$tabid_q");
			$slashdb->sqlUpdate("firehose_tab", { tabname => $tabname }, "tabid=$tabid_q");
			$slashdb->setUser($user->{uid}, { last_fhtab_set => $slashdb->getTime() });
		}
	}

	my $opts = $firehose->getAndSetOptions();
	my $html = {};
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs}, options => $opts, section => $form->{section} }, { Return => 1});
	$html->{message_area} = $message;
	return Data::JavaScript::Anon->anon_dump({
		html	=> $html
	});
}


sub ajaxGetUserFirehose {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};
	my $globjid;

	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});

	my $item = $firehose_reader->getFireHose($id);
	if ($item) {
		$globjid = $item->{globjid};
	}
#	print STDERR "ajaxGetUserFirehose id: $id globjid: $globjid\n\n";
#print STDERR scalar(localtime) . " ajaxGetUserFirehose for stoid=$stoid sidenc=$sidenc tr=$tags_reader\n";
	if (!$globjid || $globjid !~ /^\d+$/ || $user->{is_anon} || !$tags_reader) {
		return getData('error', {}, 'tags');
	}
	my $uid = $user->{uid};

	my $tags_ar = $tags_reader->getTagsByGlobjid($globjid, { uid => $uid });
	my @tags = sort  map { $_->{tagname} } @$tags_ar;
#print STDERR scalar(localtime) . " ajaxGetUserFirehose for stoid=$stoid uid=$uid tags: '@tags' tags_ar: " . Dumper($tags_ar);

	my @newtagspreload = @tags;
	push @newtagspreload,
		grep { $tags_reader->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{newtagspreloadtext} || '');
	my $newtagspreloadtext = join ' ', @newtagspreload;
	#print STDERR "ajaxGetUserFirehose $newtagspreloadtext\n\n";

	return slashDisplay($form->{nodnix} ? 'tagsnodnixuser' : 'tagsfirehosedivuser', {
		id =>		$id,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });
}

sub ajaxGetAdminFirehose {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};

	if (!$id || !$user->{is_admin}) {
		return getData('error', {}, 'tags');
	}

	return slashDisplay('tagsfirehosedivadmin', {
		id =>		$id,
		tags_admin_str =>	'',
	}, { Return => 1 });
}



sub ajaxFireHoseGetUpdates {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $start = Time::HiRes::time();

	slashProfInit();

	my $update_data = { removals => 0, items => 0, updates => 0, new => 0 };

	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $id_str = $form->{ids};
	my $update_time = $form->{updatetime};
	my @ids = grep {/^(\d+|day-\d+)$/} split (/,/, $id_str);
	my %ids = map { $_ => 1 } @ids;
	my %ids_orig = ( %ids ) ;
	my $opts = $firehose->getAndSetOptions({ no_set => 1 });
	slashProf("firehose_update_gfe");
	my($items, $results, $count, $future_count, $day_num, $day_label, $day_count) = $firehose_reader->getFireHoseEssentials($opts);
	slashProf("","firehose_update_gfe");
	my $num_items = scalar @$items;
	my $future = {};
	my $globjs = [];
	my $base_page = "firehose.pl";
	if ($form->{fh_pageval}) {
		if ($form->{fh_pageval} == 1) {
			$base_page = "console.pl";
		} elsif ($form->{fh_pageval} == 2) {
			$base_page = "users.pl";
		}
	}
	
	$update_data->{items} = scalar @$items;

	foreach (@$items) {
		push @$globjs, $_->{globjid} if $_->{globjid} 
	}


	if ($opts->{orderby} eq "createtime") {
		$items = $firehose->addDayBreaks($items, $user->{off_set});
	}

	my $votes = $firehose->getUserFireHoseVotesForGlobjs($user->{uid}, $globjs);
	my $html = {};
	my $updates = [];

	my $adminmode = $user->{is_admin};
	$adminmode = 0 if $user->{is_admin} && $user->{firehose_usermode};
	my $ordered = [];
	my $now = $slashdb->getTime();
	my $added = {};

	my $last_day;
	my $mode = $opts->{mode};
	my $curmode = $opts->{mode};
	my $mixed_abbrev_pop = $firehose->getMinPopularityForColorLevel(1);

	foreach (@$items) {
		if ($opts->{mixedmode}) {
			$curmode = "full";
			$curmode = "fulltitle" if $_->{popularity} < $mixed_abbrev_pop;

		}
		my $item = {};
		if (!$_->{day}) {
			$item = $firehose_reader->getFireHose($_->{id});
			$last_day = timeCalc($item->{createtime}, "%Y%m%d");
		}
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		$future->{$_->{id}} = 1 if $item->{createtime} gt $now;
		if ($ids{$_->{id}}) {
			if ($item->{last_update} ge $update_time) {
				if (!$item->{day}) {
					my $url 	= $slashdb->getUrl($item->{url_id});
					my $the_user  	= $slashdb->getUser($item->{uid});
					$html->{"title-$_->{id}"} = slashDisplay("formatHoseTitle", { adminmode => $adminmode, item => $item, showtitle => 1, url => $url, the_user => $the_user, options => $opts }, { Return => 1 });
					$html->{"tags-top-$_->{id}"} = slashDisplay("firehose_tags_top", { tags_top => $tags_top, id => $_->{id}, item => $item }, { Return => 1 });
					my $introtext = $item->{introtext};
					slashDisplay("formatHoseIntro", { introtext => $introtext, url => $url, $item => $item }, { Return => 1 });
					$html->{"text-$_->{id}"} = $introtext;
					$html->{"fhtime-$_->{id}"} = timeCalc($item->{createtime});
					$html->{"topic-$_->{id}"} = slashDisplay("dispTopicFireHose", { item => $item, adminmode => $adminmode }, { Return => 1});
					$update_data->{updates}++;
					# updated
				}
			}
		} else {
			# new
			$update_time = $_->{last_update} if $_->{last_update} gt $update_time && $_->{last_update} lt $now;
			if ($_->{day}) {
				push @$updates, ["add", $_->{id}, slashDisplay("daybreak", { options => $opts, cur_day => $_->{day}, last_day => $_->{last_day}, id => "firehose-day-$_->{day}", fh_page => $base_page }, { Return => 1, Page => "firehose" }) ];
			} else {
				$update_data->{new}++;
				my $data = {
					mode => $curmode,
					item => $item,
					tags_top => $tags_top,
					vote => $votes->{$item->{globjid}},
					options => $opts
				};
				slashProf("firehosedisp");
				push @$updates, ["add", $_->{id}, $firehose->dispFireHose($item, $data) ];
				slashProf("","firehosedisp");
			}
			$added->{$_->{id}}++;
		}
		push @$ordered, $_->{id};
		delete $ids{$_->{id}};
	}

	my $prev;
	my $next_to_old = {};
	my $i = 0;
	my $pos;

	foreach (@$ordered) {
		$next_to_old->{$prev} = $_ if $prev && $ids_orig{$_} && $added->{$prev};
		$next_to_old->{$_} = $prev if $ids_orig{$prev} && $added->{$_};
		$prev = $_;
		$pos->{$_} = $i;
		$i++;
	}

	my $target_pos = 100;
	if (scalar (keys %$next_to_old) == 1) {
		my ($key) = keys %$next_to_old;
		$target_pos = $pos->{$key};
		
	}
	
	@$updates  = sort {
		$next_to_old->{$a->[1]} <=> $next_to_old->{$b->[1]} ||
		abs($pos->{$b->[1]} - $target_pos) <=> abs($pos->{$a->[1]} - $target_pos);
	} @$updates;

	foreach (keys %ids) {
		push @$updates, ["remove", $_, ""];
		$update_data->{removals}++;
	}
	
	my $firehose_more_data = { 
		future_count => $future_count, 
		options => $opts,
		day_num	=> $day_num,
		day_label => $day_label, 
		day_count => $day_count,
		contentsonly => 0,
	};


	$html->{'fh-paginate'} = slashDisplay("paginate", {
		contentsonly	=> 1,
		day		=> $last_day,
		last_day	=> $last_day,
		page		=> $form->{page},
		options		=> $opts,
		ulid		=> "fh-paginate",
		divid		=> "fh-pag-div",
		num_items	=> $num_items,
		fh_page		=> $base_page,
		firehose_more_data => $firehose_more_data,
		split_refresh	=> 1
	}, { Return => 1, Page => "firehose" });

	$html->{firehose_pages} = slashDisplay("firehose_pages", {
		page		=> $form->{page},
		num_items	=> $num_items,
		fh_page		=> $base_page,
		options		=> $opts,
		contentsonly	=> 1,
		search_results	=> $results
	}, { Return => 1 });

	my $recent = $slashdb->getTime({ add_secs => "-300"});
	$update_time = $recent if $recent gt $update_time;

	$html->{local_last_update_time} = timeCalc($slashdb->getTime(), "%H:%M");
	$html->{filter_text} = "Filtered to ".strip_literal($opts->{color})." '".strip_literal($opts->{fhfilter})."'";
	$html->{gmt_update_time} = " (".timeCalc($slashdb->getTime(), "%H:%M", 0)." GMT) " if $user->{is_admin};
	$html->{itemsreturned} = $num_items == 0 ?  getData("noitems", { options => $opts }, 'firehose') : "";
#	$html->{firehose_more} = getData("firehose_more_link", { options => $opts, future_count => $future_count, contentsonly => 1, day_label => $day_label, day_count => $day_count }, 'firehose');

	my $data_dump =  Data::JavaScript::Anon->anon_dump({
		html		=> $html,
		updates		=> $updates,
		update_time	=> $update_time,
		update_data	=> $update_data,
		ordered		=> $ordered,
		future		=> $future,
	});
	my $reskey_dump = "";
	my $update_time_dump;
	my $reskey = getObject("Slash::ResKey");
	my $user_rkey = $reskey->key('ajax_user_static', { no_state => 1 });
	$reskey_dump .= "reskey_static = '" . $user_rkey->reskey() . "';\n" if $user_rkey->create();

	my $duration = Time::HiRes::time() - $start;
	my $more_num = $options->{more_num} || 0;

	$update_time_dump = "update_time= ".Data::JavaScript::Anon->anon_dump($update_time);
	my $retval =  "$data_dump\n$reskey_dump\n$update_time_dump";

	my $updatelog = {
		uid 		=> $user->{uid},
		new_count 	=> $update_data->{new},
		update_count	=> $update_data->{updates},
		total_num	=> $update_data->{items},
		more_num	=> $more_num,
		"-ts"		=> "NOW()",
		duration	=> $duration,
		bytes 		=> length($retval)
	};
	$firehose->createUpdateLog($updatelog);
	slashProfEnd();

	return $retval;

}

sub firehose_vote {
	my($self, $id, $uid, $dir) = @_;

	my $tag; 
	my $constants = getCurrentStatic();
	my $tags = getObject('Slash::Tags');
	my $item = $self->getFireHose($id);
	return if !$item;
	
	my $upvote   = $constants->{tags_upvote_tagname}   || 'nod';
	my $downvote = $constants->{tags_downvote_tagname} || 'nix';
	
	if ($dir eq "+") {
		$tag = $upvote;
	} elsif ($dir eq "-") {
		$tag = $downvote;
	}
	return if !$tag;

	$tags->createTag({
		uid 		=> $uid,
		name		=> $tag,
		globjid		=> $item->{globjid},
		private		=> 1
	});
}

sub ajaxUpDownFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $id = $form->{id};
	return unless $id;

	my $firehose = getObject('Slash::FireHose');
	my $item = $firehose->getFireHose($id);
	my $tags = getObject('Slash::Tags');

	my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});

	$firehose->firehose_vote($id, $user->{uid}, $form->{dir});
	
	my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $itemid,
		{ uid => $user->{uid}, include_private => 1 });
	my $newtagspreloadtext = join ' ', sort map { $_->{tagname} } @$now_tags_ar;

	my $html  = {};
	my $value = {};

	my $votetype = $form->{dir} eq "+" ? "Up" : $form->{dir} eq "-" ? "Down" : "";
	#$html->{"updown-$id"} = "Voted $votetype";
	$value->{"newtags-$id"} = $newtagspreloadtext;

	if ($user->{is_admin}) {
		$firehose->setFireHoseSession($id, "rating");
	}

	return Data::JavaScript::Anon->anon_dump({
		html	=> $html,
		value	=> $value
	});
}

sub ajaxCreateForFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $id = $form->{id};
	my $tags = getObject('Slash::Tags');
	my $tagsstring = $form->{tags};
	my $firehose = getObject('Slash::FireHose');

	if (!$id || $user->{is_anon} || !$tags) {
		return getData('error', {}, 'tags');
	}
	my $item = $firehose->getFireHose($id);
	if (!$item || !$item->{globjid}) {
		return getData('error', {}, 'tags');
	}
	my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});
	if (!$itemid || !$table) {
		return getData('error', {}, 'tags');
	}
	my $newtagspreloadtext = $tags->setTagsForGlobj($itemid, $table, $tagsstring);

	if ($user->{is_admin}) {
		$firehose->setSectionTopicsFromTagstring($id, $tagsstring);
	}

	my $retval = slashDisplay('tagsfirehosedivuser', {
		id =>		$id,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });

#print STDERR scalar(localtime) . " ajaxCreateForFirehose 4 for id=$id tagnames='@tagnames' newtagspreloadtext='$newtagspreloadtext' returning: $retval\n";

	return $retval;
}

sub ajaxGetFormContents {
	my($slashdb, $constants, $user, $form) = @_;
	return unless $user->{is_admin} && $form->{id};
	my $firehose = getObject("Slash::FireHose");
	my $id = $form->{id};
	my $item = $firehose->getFireHose($id);
	return unless $item;
	my $url;
	$url = $slashdb->getUrl($item->{url_id}) if $item->{url_id};
	my $the_user = $slashdb->getUser($item->{uid});
	slashDisplay('fireHoseForm', { item => $item, url => $url, the_user => $the_user }, { Return => 1});
}

sub ajaxGetAdminExtras {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	return unless $user->{is_admin} && $form->{id};
	my $firehose = getObject("Slash::FireHose");
	my $item = $firehose->getFireHose($form->{id});
	return unless $item;
	my $subnotes_ref = $firehose->getMemoryForItem($item);
	my $similar_stories = $firehose->getSimilarForItem($item);
	my $num_from_uid = 0;
	my $accepted_from_uid = 0;
	my $num_with_emaildomain = 0;
	my $accepted_from_emaildomain = 0;
	my $num_with_ipid = 0;
	my $accepted_from_ipid = 0;
	if ($item->{type} eq "submission") {
		$accepted_from_uid = $slashdb->countSubmissionsFromUID($item->{uid}, { del => 2 });
		$num_from_uid = $slashdb->countSubmissionsFromUID($item->{uid});
		$accepted_from_emaildomain = $slashdb->countSubmissionsWithEmaildomain($item->{emaildomain}, { del => 2 });
		$num_with_emaildomain = $slashdb->countSubmissionsWithEmaildomain($item->{emaildomain});
		$num_with_ipid = $slashdb->countSubmissionsFromIPID($item->{ipid});
		$accepted_from_ipid = $slashdb->countSubmissionsFromIPID($item->{ipid}, { del => 2});
	}

	my $the_user = $slashdb->getUser($item->{uid});

	my $byline = getData("byline", {
		item				=> $item,
		the_user			=> $the_user,
		adminmode			=> 1,
		extras 				=> 1,
		hidediv				=> 1,
		num_from_uid    		=> $num_from_uid,
		accepted_from_uid 		=> $accepted_from_uid,
		num_with_emaildomain 		=> $num_with_emaildomain,
		accepted_from_emaildomain 	=> $accepted_from_emaildomain,
		accepted_from_ipid		=> $accepted_from_ipid,
		num_with_ipid			=> $num_with_ipid,
	}, "firehose");

	my $admin_extras = slashDisplay("admin_extras", {
		item				=> $item,
		subnotes_ref			=> $subnotes_ref,
		similar_stories			=> $similar_stories,
	}, { Return => 1 });

	return Data::JavaScript::Anon->anon_dump({
		html => {
			"details-$item->{id}" 		=> $byline,
			"admin-extras-$item->{id}" 	=> $admin_extras
		}
	});
}

sub setSectionTopicsFromTagstring {
	my($self, $id, $tagstring) = @_;
	my $constants = getCurrentStatic();

	my @tags = split(/\s+/, $tagstring);
	my $data = {};

	my %categories = map { ($_, $_) } (qw(hold quik),
		(ref $constants->{submit_categories}
			? map {lc($_)} @{$constants->{submit_categories}}
			: ()
		)
	);

	foreach (@tags) {
		my $skid = $self->getSkidFromName($_);
		my $tid = $self->getTidByKeyword($_);
		if ($skid) {
			$data->{primaryskid} = $skid;
		}
		if ($tid) {
			$data->{tid} = $tid;
		}
		my($prefix, $cat) = $_ =~ /(!)?(.*)$/;
		$cat = lc($cat);
		if ($categories{$cat}) {
			if ($prefix eq "!") {
				$data->{category} = "";
			} else {
				$data->{category} = $cat;
			}
		}
	}
	$self->setFireHose($id, $data) if keys %$data > 0;

}

# Return a positive number if data was altered, 0 if it was not,
# or undef on error.

sub setFireHose {
	my($self, $id, $data) = @_;
	my $constants = getCurrentStatic();
	return undef unless $id && $data;
	return 0 if !%$data;
	my $id_q = $self->sqlQuote($id);
	
	my $mcd = $self->getMCD();
	my $mcdkey;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:firehose";
	}

	if (!exists($data->{last_update}) && !exists($data->{-last_update})) {
		my @non_trivial = grep {!/^(activity|toptags)$/} keys %$data;
		if (@non_trivial > 0) {
			$data->{-last_update} = 'NOW()';
		} else {
			$data->{-last_update} = 'last_update';
		}
	}

	# Admin notes used to be stored in firehose.note;  that column is
	# now gone and that data goes in globj_adminnote.  The note is
	# stored on the object that the firehose points to.
	if (exists $data->{note}) {
		my $note = delete $data->{note};
		# XXX once getFireHose does caching, use that instead of an sqlSelect
		my $globjid = $self->sqlSelect('globjid', 'firehose', "id=$id_q");
		warn "no globjid for firehose '$id'" if !$globjid;
		$self->setGlobjAdminnote($globjid, $note);
	}

	return 0 if !keys %$data;

	my $text_data = {};

	$text_data->{title} = delete $data->{title} if exists $data->{title};
	$text_data->{introtext} = delete $data->{introtext} if exists $data->{introtext};
	$text_data->{bodytext} = delete $data->{bodytext} if exists $data->{bodytext};
	$text_data->{media} = delete $data->{media} if exists $data->{media};

	my $rows = $self->sqlUpdate('firehose', $data, "id=$id_q");
#{ use Data::Dumper; my $dstr = Dumper($data); $dstr =~ s/\s+/ /g; print STDERR "setFireHose A rows=$rows for id=$id_q data: $dstr\n"; }
	$rows += $self->sqlUpdate('firehose_text', $text_data, "id=$id_q") if keys %$text_data;
#{ use Data::Dumper; my $dstr = Dumper($text_data); $dstr =~ s/\s+/ /g; print STDERR "setFireHose B rows=$rows for id=$id_q data: $dstr\n"; }

	if ($mcd && $constants->{firehose_mcd_disp}) {
		 $mcd->delete("$mcdkey:$id", 3);
		 my $keys = $self->genFireHoseMCDAllKeys($id);
		 foreach (@$keys) {
			$mcd->delete($_, 3);
		 }

	}

	my $searchtoo = getObject('Slash::SearchToo');
	if ($searchtoo) {
		my $status = 'changed';
# for now, no deletions ... this is what it would look like if we did!
#		$status = 'deleted' if $data->{accepted} eq 'yes' || $data->{rejected} eq 'yes';
		$searchtoo->storeRecords(firehose => $id, { $status => 1 });
	}

	return $rows;
}


# This generates the key for memcaching dispFireHose results
# if no key is returned no caching or fetching from cache will
# take place

sub genFireHoseMCDKey {
	my($self, $id, $options) = @_;
	my $gSkin = getCurrentSkin();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my $mcd = $self->getMCD();
	my $mcdkey;

	return if $gSkin->{skid} != $constants->{mainpage_skid};
	return if !$constants->{firehose_mcd_disp};

	if ($mcd && !$options->{nodates} && !$options->{nobylines} && !$options->{nocolors} && !$options->{nothumbs} && !$form->{skippop} && !$form->{index} && !$options->{vote} && !$user->{is_admin}) {
		$mcdkey = "$self->{_mcd_keyprefix}:dispfirehose-$options->{mode}:$id";
	}
	return $mcdkey;

}

sub genFireHoseMCDAllKeys {
	my($self, $id) = @_;
	my $keys = [];
	my $mcd = $self->getMCD();
	my $mcdkey;
	if ($mcd) {
		foreach my $mode (qw(full fulltitle)) {
			push @$keys, "$self->{_mcd_keyprefix}:dispfirehose-$mode:$id";
		}
	}
	return $keys;
}


sub dispFireHose {
	my($self, $item, $options) = @_;
	$options ||= {};
	my $mcd = $self->getMCD();
	my $mcdkey;
	if ($mcd) {
		$mcdkey = $self->genFireHoseMCDKey($item->{id}, $options);
		my $cached;
		if ($mcdkey) {
			$cached = $mcd->get("$mcdkey");
		}
		return $cached if $cached;
	}

	my $retval = slashDisplay('dispFireHose', {
		item			=> $item,
		mode			=> $options->{mode},
		tags_top		=> $options->{tags_top},
		options			=> $options->{options},
		vote			=> $options->{vote},
		bodycontent_include	=> $options->{bodycontent_include},
		nostorylinkwrapper	=> $options->{nostorylinkwrapper},
		view_mode		=> $options->{view_mode}
	}, { Page => "firehose",  Return => 1 });

	if ($mcd) {
		$mcdkey = $self->genFireHoseMCDKey($item->{id}, $options);
		if ($mcdkey) {
			$mcd->set($mcdkey, $retval, 180);
		}
	}
	return $retval;
}

sub getMemoryForItem {
	my($self, $item) = @_;
	my $user = getCurrentUser();
	$item = $self->getFireHose($item) if $item && !ref $item;
	return [] unless $item && $user->{is_admin};
	my $subnotes_ref = [];
	my $sub_memory = $self->getSubmissionMemory();
	my $url = "";
	$url = $self->getUrl($item->{url_id}) if $item->{url_id};

	foreach my $memory (@$sub_memory) {
		my $match = $memory->{submatch};

		if ($item->{email} =~ m/$match/i ||
		    $item->{name}  =~ m/$match/i ||
		    $item->{title}  =~ m/$match/i ||
		    $item->{ipid}  =~ m/$match/i ||
		    $item->{introtext} =~ m/$match/i ||
		    $url =~ m/$match/i) {
			push @$subnotes_ref, $memory;
		}
	}
	return $subnotes_ref;
}

sub getSimilarForItem {
	my($self, $item) = @_;
	my $user 	= getCurrentUser();
	my $constants   = getCurrentStatic();
	$item = $self->getFireHose($item) if $item && !ref $item;
	return [] unless $item && $user->{is_admin};
	my $num_sim = $constants->{similarstorynumshow} || 5;
	my $reader = getObject("Slash::DB", { db_type => "reader" });
	my $storyref = {
		title 		=> $item->{title},
		introtext 	=> $item->{introtext}
	};
	if ($item->{type} eq "story") {
		my $story = $self->getStory($item->{srcid});
		$storyref->{sid} = $story->{sid} if $story && $story->{sid};
	}
	my $similar_stories = [];
	$similar_stories = $reader->getSimilarStories($storyref, $num_sim) if $user->{is_admin};

	# Truncate that data to a reasonable size for display.

	if ($similar_stories && @$similar_stories) {
		for my $sim (@$similar_stories) {
			# Display a max of five words reported per story.
			$#{$sim->{words}} = 4 if $#{$sim->{words}} > 4;
			for my $word (@{$sim->{words}}) {
				# Max of 12 chars per word.
				$word = substr($word, 0, 12);
			}
			$sim->{title} = chopEntity($sim->{title}, 35);
		}
	}
	return $similar_stories;
}

sub getAndSetOptions {
	my($self, $opts) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $form 	= getCurrentForm();
	my $gSkin	= getCurrentSkin();

	$opts 	        ||= {};
	my $options 	= {};

	my $types = { feed => 1, bookmark => 1, submission => 1, journal => 1, story => 1, vendor => 1, misc => 1 }; 
	my $tabtypes = { tabsection => 1, tabpopular => 1, tabrecent => 1, tabuser => 1};
	
	my $tabtype = '';
	$tabtype = $form->{tabtype} if $form->{tabtype} && $tabtypes->{ $form->{tabtype} };

	my $modes = { full => 1, fulltitle => 1 };
	my $pagesizes = { "small" => 1, "large" => 1 };

	my $no_saved = $form->{no_saved};
	$opts->{no_set} ||= $no_saved;
	$opts->{initial} ||= 0;

	if (defined $form->{mixedmode} && $form->{setfield}) {
		$options->{mixedmode} = $form->{mixedmode} ? 1 : 0;
	} else {
		$options->{mixedmode} = $user->{firehose_mixedmode};
	}

	if (defined $form->{nocommentcnt} && $form->{setfield}) {
		$options->{nocommentcnt} = $form->{nocommentcnt} ? 1 : 0;
	} else {
		$options->{nocommentcnt} = $user->{firehose_nocommentcnt};
	}
	my $mode = $form->{mode} || $user->{firehose_mode} || '';
	$mode = "fulltitle" if $mode eq "mixed";

	my $pagesize = $pagesizes->{$form->{pagesize}} ? $form->{pagesize} : $user->{firehose_pagesize} || "small";
	$options->{pagesize} = $pagesize;

	$mode = $mode && $modes->{$mode} ? $mode : "fulltitle";
	$options->{mode} = $mode;
	$options->{pause} = defined $user->{firehose_pause} ? $user->{firehose_pause} : 1;
	$form->{pause} = 1 if $no_saved;

	my $firehose_page = $user->{state}{firehose_page} || '';

	if (defined $form->{pause}) {
		$options->{pause} = $user->{firehose_paused} = $form->{pause} ? 1 : 0;
		if ($firehose_page ne 'user') {
			$self->setUser($user->{uid}, { firehose_paused => $options->{pause} });
		}
	}
	if (defined $form->{duration}) {
		if ($form->{duration} =~ /^-?\d+$/) {
			$options->{duration} = $form->{duration};
		}
	}
	$options->{duration} = "7" if !$options->{duration};

	if (defined $form->{startdate}) {
		if ($form->{startdate} =~ /^\d{8}$/) {
			my ($y, $m, $d) = $form->{startdate} =~ /(\d{4})(\d{2})(\d{2})/;
			if ($y) {
				$options->{startdate} = "$y-$m-$d";
			}
		}
	}
	$options->{startdate} = "" if !$options->{startdate};
	if ($form->{issue}) {
		if ($form->{issue} =~ /^\d{8}$/) {
			my ($y, $m, $d) = $form->{issue} =~ /(\d{4})(\d{2})(\d{2})/;
			$options->{startdate} = "$y-$m-$d";
			$options->{issue} = $form->{issue};

		} else {
			$form->{issue} = "";
		}
	}
	

	my $colors = $self->getFireHoseColors();
	if ($form->{color} && $colors->{$form->{color}}) {
		$options->{color} = $form->{color};
	}
	$options->{color} ||= $user->{firehose_color};

	if ($form->{orderby}) {
		if ($form->{orderby} eq "popularity") {
			if ($user->{is_admin} && !$user->{firehose_usermode}) {
				$options->{orderby} = 'editorpop';
			} else {
				$options->{orderby} = 'popularity';
			}
		} else {
			$options->{orderby} = "createtime";
		}

	} else {
		$options->{orderby} = $user->{firehose_orderby} unless $no_saved;
		$options->{orderby} ||= 'createtime';
	}

	if ($form->{orderdir}) {
		if (uc($form->{orderdir}) eq "ASC") {
			$options->{orderdir} = "ASC";
		} else {
			$options->{orderdir} = "DESC";
		}

	} else {
		$options->{orderdir} = $user->{firehose_orderdir} unless $no_saved;
		$options->{orderdir} ||= 'DESC';
	}

	my $fhfilter;

	if ($opts->{initial}) {
		if (!defined $form->{section}) {
			$form->{section} = $gSkin->{skid} == $constants->{mainpage_skid} ? 0 : $gSkin->{skid};
		}
		if (!$tabtype) {
			$tabtype = 'tabsection';
		}
	}

	my $the_skin = defined $form->{section} ? $self->getSkin($form->{section}) : $gSkin;

	if ($tabtype eq 'tabsection') {
		$form->{fhfilter} = "story";
		$options->{orderdir} = "DESC";
		$options->{orderby} = "createtime";
		$options->{color} = "black";
		$form->{color} = "black";
	} elsif ($tabtype eq 'tabrecent') {
		$form->{fhfilter} = "-story";
		$options->{orderby} = "createtime";
		$options->{orderdir} = "DESC";
		$options->{color} = "indigo";
		$form->{color} = "indigo";
	} elsif ($tabtype eq 'tabpopular') {
		$form->{fhfilter} = "-story";
		$options->{orderby} = "popularity";
		$options->{orderdir} = "DESC";
		$options->{color} = "black";
		$form->{color} = "black";
	} elsif ($tabtype eq 'tabuser') {
		$form->{fhfilter} = "\"user:$user->{nickname}\"";
		$options->{orderby} = "popularity";
		$options->{color} = "black";
		$form->{color} = "black";
		$options->{orderdir} = "DESC";
		$options->{orderby} = "createtime";
	}

	if ($tabtype) {
		$form->{fhfilter} = "$the_skin->{name} $form->{fhfilter}" if $the_skin->{skid} != $constants->{mainpage_skid};
	}


	if (defined $form->{fhfilter}) {
		$fhfilter = $form->{fhfilter};
		$options->{fhfilter} = $fhfilter;
	} else {
		$fhfilter = $user->{firehose_fhfilter} unless $no_saved;
		$options->{fhfilter} = $fhfilter;
	}

	my $user_tabs = $self->getUserTabs();
	my %user_tab_names = map { $_->{tabname} => 1 } @$user_tabs;
	my @tab_fields = qw(tabname filter mode color orderdir orderby);

	$user_tabs = $self->getUserTabs();


	my $skin_prefix="";
	if ($the_skin && $the_skin->{name} && $the_skin->{skid} != $constants->{mainpage_skid})  {
		$skin_prefix = "$the_skin->{name} ";
	}
	my $system_tabs = [ 
		{ tabtype => 'tabsection', color => 'black', filter => $skin_prefix . "story", orderby => 'createtime'},
		{ tabtype => 'tabpopular', color => 'black', filter => "$skin_prefix\-story", orderby => 'popularity'},
		{ tabtype => 'tabrecent',  color => 'indigo',  filter => "$skin_prefix\-story", orderby => 'createtime'},
	];

	if (!$user->{is_anon}) {
		push @$system_tabs, { tabtype => 'tabuser', color => 'black', filter => $skin_prefix . "\"user:$user->{nickname}\""};
	}

	my $sel_tabtype;

	my $tab_compare = { 
		color 		=> "color", 
		filter 		=> "fhfilter" 
	};

	my $tab_match = 0;
	foreach my $tab (@$user_tabs, @$system_tabs) {
		my $equal = 1;

		my $this_tab_compare;
		%$this_tab_compare = %$tab_compare;

		$this_tab_compare->{orderby} = 'orderby' if defined $tab->{tabtype};
		

		foreach (keys %$this_tab_compare) {
			$options->{$this_tab_compare->{$_}} ||= "";
			if ($tab->{$_} ne $options->{$this_tab_compare->{$_}}) {
				$equal = 0;
			}
		}
		if ($equal) {
			$tab_match = 1;
			$tab->{active} = 1;
			if (defined $tab->{tabtype}) {
				$sel_tabtype = $tab->{tabtype};
			}
			
			# Tab match if new option is being set update tab
			if ($form->{orderdir} || $form->{orderby} || $form->{mode}) {
				
				my $data = {};
				$data->{orderdir} = $options->{orderdir};
				$data->{orderby}  = $options->{orderby};
				$data->{mode}  	  = $options->{mode};
				$data->{filter}	  = $options->{fhfilter};
				$data->{color}	  = $options->{color};
				if (!$user->{is_anon} && $tab->{tabname}) {
					$self->createOrReplaceUserTab($user->{uid}, $tab->{tabname}, $data) ;
				}
			}
		}
	}

	if (!$tab_match) {
		my $data = {};
		foreach (keys %$tab_compare) {
			$data->{$_} = $options->{$tab_compare->{$_}} || '';
		}
		if (!$user->{is_anon}) {
			$self->createOrReplaceUserTab($user->{uid}, "untitled", $data);
		}
		$user_tabs = $self->getUserTabs();
		foreach (@$user_tabs) {
			$_->{active} = 1 if $_->{tabname} eq "untitled" 
		}
	}

	if (defined $form->{tab}) {
		my $tabnames_hr = {};
		foreach (@$user_tabs) {
			$tabnames_hr->{$_->{tabname}} = $_;
		}
		if ($tabnames_hr->{$form->{tab}}) {
			my $curtab = $tabnames_hr->{$form->{tab}};
			$options->{color} = $curtab->{color};
			$fhfilter = $options->{fhfilter} = $curtab->{filter};
			$options->{mode} = $curtab->{mode};
			$options->{orderby} = $curtab->{orderby};
			$options->{orderdir} = $curtab->{orderdir};

			$_->{active} = $_->{tabname} eq $form->{tab} ? 1 : 0  foreach @$user_tabs;
		}
	}

	if ($form->{index}) {
		$mode = "fulltitle";
		if (getCurrentSkin()->{nexus} != $constants->{mainpage_nexus_tid}) {
			$mode = "full";
		}
	}

	# number of firehose items per page in the normal case
	if ($mode eq "full") {
		if ($user->{is_admin}) {
			$options->{limit} = $pagesize eq "large" ? 50 : 25;
		} else {
			$options->{limit} = $pagesize eq "large" ? 25 : 15;
		}
	} else {
		if ($user->{is_admin}) {
			$options->{limit} = 50;
		} else {
			$options->{limit} = $pagesize eq "large" ? 30 : 25;
		}
	}

	# the non-normal cases: a small device (e.g., iPhone) or an embedded use (e.g., Google Gadget)
	my $force_smaller = $form->{embed};
	if (!$force_smaller && $constants->{smalldevices_ua_regex}) {
		my $smalldev_re = qr($constants->{smalldevices_ua_regex});
		if ($ENV{HTTP_USER_AGENT} && $ENV{HTTP_USER_AGENT} =~ $smalldev_re) {
			$force_smaller = 1;
		}
	}

	# ...for which we'll have fewer items per page
	if ($force_smaller) {
		$options->{smalldevices} = 1;
		$options->{limit} = 10;
	}

	if ($user->{is_admin} && $form->{setusermode}) {
		$self->setUser($user->{uid}, { firehose_usermode => $form->{firehose_usermode} ? 1 : "" });
	}

	foreach (qw(nodates nobylines nothumbs nocolors noslashboxes nomarquee)) {
		if ($form->{setfield}) {
			if (defined $form->{$_}) {
				$options->{$_} = $form->{$_} ? 1 : 0;
			} else {
				$options->{$_} = $user->{"firehose_$_"};
			}
		}
		$options->{$_} = defined $form->{$_} ? $form->{$_} : $user->{"firehose_$_"};
	}

	my $page = $form->{page} || 0;
	$options->{page} = $page;
	if ($page) {
		$options->{offset} = $page * $options->{limit};
	}


	$fhfilter =~ s/^\s+|\s+$//g;
	if ($form->{index}) {
		$fhfilter = "story";
		my $gSkin = getCurrentSkin();
		if ($gSkin->{nexus} != $constants->{mainpage_nexus_tid}) {
			$fhfilter .= " $gSkin->{name}";
		}
	}
	my $fh_ops = $self->splitOpsFromString($fhfilter);
	

	my $skins = $self->getSkins();
	my %skin_names = map { $skins->{$_}{name} => $_ } keys %$skins;

	my %categories = map { ($_, $_) } (qw(hold quik),
		(ref $constants->{submit_categories}
			? map {lc($_)} @{$constants->{submit_categories}}
			: ()
		)
	);

	my $authors = $self->getAuthors();
	my %author_names = map { lc($authors->{$_}{nickname}) => $_ } keys %$authors;
	my $fh_options = {};



	foreach (@$fh_ops) {
		my $not = "";
		if (/^-/) {
			$not = "not_";
			$_ =~ s/^-//g;
		}
		if ($types->{$_} && !defined $fh_options->{type}) {
			push @{$fh_options->{$not."type"}}, $_;
		} elsif ($user->{is_admin} && $categories{$_} && !defined $fh_options->{category}) {
			$fh_options->{category} = $_;
		} elsif ($skin_names{$_} && !defined $fh_options->{primaryskid}) {
				push @{$fh_options->{$not."primaryskid"}}, $skin_names{$_};
		} elsif ($user->{is_admin} && $_ eq "rejected") {
			$fh_options->{rejected} = "yes";
		} elsif ($_ eq "accepted") {
			$fh_options->{accepted} = "yes";
		} elsif ($user->{is_admin} && $_ eq "signed") {
			$fh_options->{signed} = 1;
		} elsif ($user->{is_admin} && $_ eq "unsigned") {
			$fh_options->{unsigned} = 1;
		} elsif (/^author:(.*)$/) {
			my $uid;
			my $nick = $1;
			if ($nick) {
				$uid = $self->getUserUID($nick);
				$uid ||= $user->{uid};
			}
			push @{$fh_options->{$not."uid"}}, $uid;
		} elsif (/^user:/) {
			my $nick = $_;
			$nick =~ s/user://g;
			my $uid;
			if ($nick) {
				$uid = $self->getUserUID($nick);
			}
			$uid ||= $user->{uid};
			$fh_options->{tagged_by_uid} = $uid;
			$fh_options->{tagged_non_negative} = 1;
#			$fh_options->{ignore_nix} = 1;
		} else {
			if (!defined $fh_options->{filter}) {
				$fh_options->{filter} = $_;
				$fh_options->{filter} =~ s/[^a-zA-Z0-9_-]+//g;
				$fh_options->{filter} = "-" . $fh_options->{filter} if $not;
			}
			# Don't filter this
			$fh_options->{qfilter} .= $_ . ' ';
			$fh_options->{qfilter} = '-' . $fh_options->{qfilter} if $not;
		}
	}

	if ($form->{color} && $colors->{$form->{color}}) {
		$fh_options->{color} = $form->{color};
	}

	if ($form->{index}) {
		$options->{skipmenu} = 1;
		$options->{skippop} = 1;
		if (!$form->{issue} && getCurrentSkin()->{nexus} != $constants->{mainpage_nexus_tid}) {
			$options->{duration} = -1;
			$options->{startdate} = '';
		}
		$options->{color} = 'black';
		$options->{nocolors} = 1;
		if (getCurrentSkin()->{nexus} == $constants->{mainpage_nexus_tid}) {
			$options->{mixedmode} = 1;
			$options->{mode} = 'fulltitle';
		} else {
			$options->{mode} = 'full';
			$options->{mixedmode} = 0;
		}
	}
	

	foreach (keys %$fh_options) {
		$options->{$_} = $fh_options->{$_};
	}

	if (!$user->{is_anon} && !$opts->{no_set} && !$form->{index}) {
		my $data_change = {};
		my @skip_options_save = qw(uid not_uid type not_type primaryskid not_primaryskid smalldevices);
		if ($firehose_page eq 'user') {
			push @skip_options_save, "nothumbs", "nocolors", "pause", "mode", "orderdir", "orderby", "fhfilter", "color";
		}
		my %skip_options = map { $_ => 1 } @skip_options_save;
		foreach (keys %$options) {
			next if $skip_options{$_};
			$data_change->{"firehose_$_"} = $options->{$_} if !defined $user->{"firehose_$_"} || $user->{"firehose_$_"} ne $options->{$_};
		}
		$self->setUser($user->{uid}, $data_change) if keys %$data_change > 0;
	}

	$options->{tabs} = $user_tabs;
	$options->{sel_tabtype} = $sel_tabtype;

	if ($user->{is_admin} && $form->{setusermode}) {
		$options->{firehose_usermode} = $form->{firehose_usermode} ? 1 : "";
	}

	my $adminmode = 0;
	$adminmode = 1 if $user->{is_admin};
	if ($no_saved) {
		$adminmode = 0;
	} elsif (defined $options->{firehose_usermode}) {
		$adminmode = 0 if $options->{firehose_usermode};
	} else {
		$adminmode = 0 if $user->{firehose_usermode};
	}

	$options->{public} = "yes";
	if ($adminmode) {
		# $options->{attention_needed} = "yes";
		if ($firehose_page ne "user") {
			$options->{accepted} = "no" if !$options->{accepted};
			$options->{rejected} = "no" if !$options->{rejected};
		}
		$options->{duration} ||= -1;
	} else  {
		if ($firehose_page ne "user") {
			$options->{accepted} = "no" if !$options->{accepted};
		}
		
		$options->{duration} ||= 1;
		if ($user->{is_subscriber} && !$no_saved) {
			$options->{createtime_subscriber_future} = 1;
		} else {
			$options->{createtime_no_future} = 1;
		}
	}

	if ($options->{issue}) {
		$options->{duration} = 1;
	}

	if ($form->{not_id} && $form->{not_id} =~ /^\d+$/) {
		$options->{not_id} = $form->{not_id};
	}


	if ($form->{more_num} && $form->{more_num} =~ /^\d+$/) {
		$options->{more_num} = $form->{more_num};
		if (!$user->{is_admin} && (($options->{limit} + $options->{more_num}) > 200)) {
			$options->{more_num} = 200 - $options->{limit} ;
		}
		if ($options->{more_num} > $user->{firehose_max_more_num}) {
			$self->setUser($user->{uid}, { firehose_max_more_num => $options->{more_num}});
		}
	}

	return $options;
}

sub getFireHoseTagsTop {
	my($self, $item) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $form = getCurrentForm();
	my $tags_top	 = [];

	# The meaning of the number after the colon is referenced in
	# firehose_tags_top;misc;default and (if nonzero) is passed to
	# YAHOO.slashdot.gCompleterWidget.attach().
	if ($user->{is_admin}) {
		if ($item->{type} eq "story") {
			# 5 = add completer_handleNeverDisplay
			push @$tags_top, "$item->{type}:5";
		} else {
			push @$tags_top, "$item->{type}:6";
		}
	} else {
		push @$tags_top, $item->{type};
	}
	
	if ($item->{primaryskid} && $item->{primaryskid} != $constants->{mainpage_skid}) {
		my $the_skin = $self->getSkin($item->{primaryskid});
		push @$tags_top, "$the_skin->{name}:2";
	}
	if ($item->{tid}) {
		my $the_topic = $self->getTopic($item->{tid});
		push @$tags_top, "$the_topic->{keyword}:3";
	}
	my %seen_tags = map { $_ => 1 } @$tags_top;
	
	# 0 = is a link, not a menu
	my $user_tags_top = [];
	push @$user_tags_top, map { "$_:0" } grep {!$seen_tags{$_}} split (/\s+/, $item->{toptags});

	if ($constants->{smalldevices_ua_regex}) {
		my $smalldev_re = qr($constants->{smalldevices_ua_regex});
		if ($ENV{HTTP_USER_AGENT} =~ $smalldev_re) {
			$#{@$user_tags_top} = 2;
		}
	}

	if ($form->{embed}) {
		$#{@$user_tags_top} = 2;
	}

	push @$tags_top, @$user_tags_top;

	
	return $tags_top;
}

sub getMinPopularityForColorLevel {
	my($self, $level) = @_;
	my $constants = getCurrentStatic();
	my $slicepoints = $constants->{firehose_slice_points};
	my @levels = split / /, $slicepoints;
	my $entry_min = $levels[$level-1];
	my($entry, $min) = split /,/, $entry_min;
	return $min;
}

sub getEntryPopularityForColorLevel {
	my($self, $level) = @_;
	my $constants = getCurrentStatic();
	my $slicepoints = $constants->{firehose_slice_points};
	my @levels = split / /, $slicepoints;
	my $entry_min = $levels[$level-1];
	my($entry, $min) = split /,/, $entry_min;
	return $entry;
}

sub getPopLevelForPopularity {
	my($self, $pop) = @_;
	my $constants = getCurrentStatic();
	my $slicepoints = $constants->{firehose_slice_points};
	my @levels = split / /, $slicepoints;
	for my $i (0..$#levels) {
		my $entry_min = $levels[$i];
		my($entry, $min) = split /,/, $entry_min;
		return $i+1 if $pop >= $min;
	}
	# This should not happen, since the min value for the last slice
	# is supposed to be very large negative.  If a score goes below
	# it, though, return the next slice number.
	return $#levels + 1;
}

sub listView {
	my($self, $lv_opts) = @_;
	$lv_opts ||= {};
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();

	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $featured;

	if ($gSkin->{name} eq "idle" && !$user->{firehose_nomarquee}) {
		my $featured_ops ={ primaryskid => $gSkin->{skid}, type => "story", limit => 1, orderby => 'createtime', orderdir => 'DESC'};

		if ($user->{is_subscriber}) {
			$featured_ops->{createtime_subscriber_future} = 1;
		} else {
			$featured_ops->{createtime_no_future} = 1;
		}

		my($res) = $firehose_reader->getFireHoseEssentials($featured_ops);
		if ($res && $res->[0]) {
			$featured = $firehose_reader->getFireHose($res->[0]->{id});
		}
	}
	my $initial = ($form->{tab} || $form->{tabtype} || $form->{fhfilter} || defined $form->{page} || $lv_opts->{fh_page} eq "console.pl" || $form->{ssi} && defined $form->{fhfilter}) ? 0 : 1;

	my $options = $lv_opts->{options} || $self->getAndSetOptions({ initial => $initial });
	my $base_page = $lv_opts->{fh_page} || "firehose.pl";

	if ($featured && $featured->{id}) {
		$options->{not_id} = $featured->{id};
	}
	slashProf("get_fhe");
	my($items, $results, $count, $future_count, $day_num, $day_label, $day_count) = $firehose_reader->getFireHoseEssentials($options);
	slashProf("","get_fhe");

	my $itemnum = scalar @$items;

	my $globjs;

	foreach (@$items) {
		push @$globjs, $_->{globjid} if $_->{globjid} 
	}

	if ($options->{orderby} eq "createtime") {
		$items = $self->addDayBreaks($items, $user->{off_set});
	}

	my $votes = $self->getUserFireHoseVotesForGlobjs($user->{uid}, $globjs);

	my $itemstext;
	my $maxtime = $slashdb->getTime();
	my $now = $slashdb->getTime();
	my $colors = $self->getFireHoseColors(1);
	my $colors_hash = $self->getFireHoseColors();

	my $i=0;
	my $last_day = 0;

	my $mode = $options->{mode};
	my $curmode = $options->{mode};
	my $mixed_abbrev_pop = $self->getMinPopularityForColorLevel(1);
	my $constants = getCurrentStatic();
	
	foreach (@$items) {
		if ($options->{mixedmode}) {
			$curmode = "full";
			$curmode = "fulltitle" if $_->{popularity} < $mixed_abbrev_pop;

		}
		$maxtime = $_->{createtime} if $_->{createtime} gt $maxtime && $_->{createtime} lt $now;
		my $item =  $firehose_reader->getFireHose($_->{id});
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		if ($_->{day}) {
			my $day = $_->{day};
			$day =~ s/ \d{2}:\d{2}:\d{2}$//;
			$itemstext .= slashDisplay("daybreak", { options => $options, cur_day => $day, last_day => $_->{last_day}, id => "firehose-day-$day", fh_page => $base_page }, { Return => 1, Page => "firehose" });
		} else {
	$last_day = timeCalc($item->{createtime}, "%Y%m%d");
			slashProf("firehosedisp");
			$itemstext .= $self->dispFireHose($item, {
				mode			=> $curmode,
				tags_top		=> $tags_top,
				options			=> $options,
				vote			=> $votes->{$item->{globjid}},
				bodycontent_include	=> $user->{is_anon} 
			});
			slashProf("","firehosedisp");
		}
		$i++;
	}
	my $Slashboxes = displaySlashboxes($gSkin);
	my $refresh_options;
	$refresh_options->{maxtime} = $maxtime;
	if (uc($options->{orderdir}) eq "ASC") {
		$refresh_options->{insert_new_at} = "bottom";
	} else {
		$refresh_options->{insert_new_at} = "top";
	}
	
	my $section = 0;
	if ($gSkin->{skid} != $constants->{mainpage_skid}) {
		$section = $gSkin->{skid};
	}
	my $firehose_more_data = { 
		future_count => $future_count, 
		options => $options,
		day_num	=> $day_num,
		day_label => $day_label, 
		day_count => $day_count
	};

	slashDisplay("list", {
		itemstext		=> $itemstext, 
		itemnum			=> $itemnum,
		page			=> $options->{page}, 
		options			=> $options,
		refresh_options		=> $refresh_options,
		votes			=> $votes,
		colors			=> $colors,
		colors_hash		=> $colors_hash,
		tabs			=> $options->{tabs},
		slashboxes		=> $Slashboxes,
		last_day		=> $last_day,
		fh_page			=> $base_page,
		search_results		=> $results,
		featured		=> $featured,
		section			=> $section,
		firehose_more_data 	=> $firehose_more_data
	}, { Page => "firehose", Return => 1 });
}

sub setFireHoseSession {
	my ($self, $id, $action) = @_;
	my $user = getCurrentUser();
	my $item = $self->getFireHose($id);

	$action ||= "reviewing";

	my $data = {};
	$data->{lasttitle} = $item->{title};
	if ($item->{type} eq "story") {
		my $story = $self->getStory($item->{srcid});
		$data->{last_sid} = $story->{sid} if $story && $story->{sid};
	} 

	if (!$data->{last_sid}) {
		$data->{last_fhid} = $item->{id};
	}
	$data->{last_subid} ||= '';
	$data->{last_sid} ||= '';
	$data->{last_action} = $action;
	$self->setSession($user->{uid}, $data);
}

sub getUserTabs {
	my($self, $options) = @_;
	$options ||= {};
	my $user = getCurrentUser();
	my $uid_q = $self->sqlQuote($user->{uid});
	my @where = ( );
	push @where, "uid=$uid_q";
	push @where, "tabname LIKE '$options->{prefix}%'" if $options->{prefix};
	my $where = join ' AND ', @where;

	my $tabs = $self->sqlSelectAllHashrefArray("*", "firehose_tab", $where, "ORDER BY tabname ASC");
	@$tabs = sort { 
			$b->{tabname} eq "untitled" ? -1 : 
				$a->{tabname} eq "untitled" ? 1 : 0	||
			$b->{tabname} eq "User" ? -1 : 
				$a->{tabname} eq "User" ? 1 : 0	||
			$a->{tabname} cmp $b->{tabname} 
	} @$tabs;
	return $tabs;
}

sub getSystemDefaultTabs {
	my($self) = @_;
	return $self->sqlSelectAllHashrefArray("*", "firehose_tab", "uid='0'")
}

sub createUserTab {
	my($self, $uid, $data) = @_;
	$data->{uid} = $uid;
	$self->sqlInsert("firehose_tab", $data);
}

sub createOrReplaceUserTab {
	my($self, $uid, $name, $data) = @_;
	return if !$uid;
	$data ||= {};
	$data->{uid} = $uid;
	$data->{tabname} = $name;
	$self->sqlReplace("firehose_tab", $data);
}

sub ajaxFirehoseListTabs {
	my($slashdb, $constants, $user, $form) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $tabs = $firehose->getUserTabs({ prefix => $form->{prefix}});
	@$tabs = map { $_->{tabname}} grep { $_->{tabname} ne "untitled" } @$tabs;
	return join "\n", @$tabs, "untit";
}

sub splitOpsFromString {
	my ($self, $str) = @_;
	my @fh_ops_orig = map { lc($_) } split((/\s+|"/), $str);
	my @fh_ops;
	
	my $in_quotes = 0;
	my $cur_op = "";
	foreach (@fh_ops_orig) {
		if (!$in_quotes && $_ eq '"') {
			$in_quotes = 1;
		} elsif ($in_quotes) {
			if ($_ eq '"') {
				push @fh_ops, $cur_op;
				$cur_op = "";
				$in_quotes = 0;
			} else {
				$cur_op .= $_;
			}
		} elsif (/\S+/) {
			push @fh_ops, $_;
		}
	}
	return \@fh_ops;
}

sub addDayBreaks {
	my($self, $items, $offset) = @_;
	my @retitems;
	my $last_day = "00000000";
	my $days_processed = 0;
	my $last_days_processed = 0;
	foreach (@$items) {
		my $cur_day = $_->{createtime};
		$cur_day =  timeCalc($cur_day, "%Y%m%d", $offset);
		if ($cur_day ne $last_day) {
			if ($last_days_processed >= 5) {
				push @retitems, { id => "day-$cur_day", day => $cur_day, last_day => $last_day };
			}
			$last_days_processed = 0;
		} else {
			$last_days_processed++;
		}
		
		push @retitems, $_;
		$last_day = $cur_day;
		$days_processed++;
	}

	return \@retitems;
}

sub getOlderMonthsFromDay {
	my($self, $day, $start, $end) = @_;
	$day =~ s/-//g;
	$day ||= $self->getDay(0);
	my $cur_day = $self->getDay(0);

	my($y, $m, $d) = $day =~/(\d{4})(\d{2})(\d{2})/;
	my($cy, $cm, $cd) = $cur_day =~/(\d{4})(\d{2})(\d{2})/;

	$d = "01";

	my $days = [];

	for ($start..$end) {
		my ($ny, $nm, $nd) = Add_Delta_YMD($y, $m, $d, 0, $_, 0);
		$nm = "0$nm" if $nm < 10;
		$nd = "0$nd" if $nd < 10;
		my $the_day = "$ny$nm$nd";
		if ($the_day le $cur_day || $_ == 0) {
			my $label = "";
			if ($ny == $cy) {
				$label = timeCalc($the_day, "%B", 0);
			} else {
				$label = timeCalc($the_day, "%B %Y", 0);
			}
			my $num_days = Days_in_Month($ny, $nm);
			my $active = $_ == 0;
			push @$days, [ $the_day, $label, $num_days, $active ];
		}
	}
	return $days;
}

sub getFireHoseItemsByUrl {
	my($self, $url_id) = @_;
	my $url_id_q = $self->sqlQuote($url_id);
	return $self->sqlSelectAllHashrefArray("*", "firehose, firehose_text", "firehose.id=firehose_text.id AND url_id = $url_id_q");
}

sub ajaxFireHoseUsage {
	my($slashdb, $constants, $user, $form) = @_;

	my $tags = getObject('Slash::Tags');
	my $downlabel = $constants->{tags_downvote_tagname} || 'nix';
	my $down_id = $tags->getTagnameidFromNameIfExists($downlabel);
	
	my $uplabel = $constants->{tags_upvote_tagname} || 'nod';
	my $up_id = $tags->getTagnameidFromNameIfExists($uplabel);
	my $data = {};


	$data->{fh_users} = $slashdb->sqlSelect("count(distinct uid)", "tags", "tagnameid in($up_id, $down_id)");
	my $d_clause = " and created_at > date_sub(now(), interval 1 day)";
	my $h_clause = " and created_at > date_sub(now(), interval 1 hour)";
	$data->{fh_users_day} = $slashdb->sqlSelect("count(distinct uid)", "tags", "tagnameid in($up_id, $down_id) $d_clause");
	$data->{fh_users_hour} = $slashdb->sqlSelect("count(distinct uid)", "tags", "tagnameid in($up_id, $down_id) $h_clause");
	$data->{tag_cnt} = $slashdb->sqlSelect("count(*)", "tags,users,firehose", "firehose.globjid=tags.globjid AND tags.uid=users.uid AND users.seclev = 1 $d_clause");
	$data->{tag_cnt_hour} = $slashdb->sqlSelect("count(*)", "tags,users,firehose", "firehose.globjid=tags.globjid AND tags.uid=users.uid AND users.seclev = 1 $h_clause");
	$data->{nod_cnt} = $slashdb->sqlSelect("count(*)", "tags,users", "tags.uid=users.uid AND users.seclev = 1 AND tagnameid in($up_id) $d_clause");
	$data->{nod_cnt_hour} = $slashdb->sqlSelect("count(*)", "tags,users", "tags.uid=users.uid AND users.seclev = 1 AND tagnameid in($up_id) $h_clause");
	$data->{nix_cnt} = $slashdb->sqlSelect("count(*)", "tags,users", "tags.uid=users.uid AND users.seclev = 1 AND tagnameid in($down_id) $d_clause");
	$data->{nix_cnt_hour} = $slashdb->sqlSelect("count(*)", "tags,users", "tags.uid=users.uid AND users.seclev = 1 AND tagnameid in($down_id) $h_clause");

	$data->{globjid_cnt} = $slashdb->sqlSelect("count(distinct globjid)", "tags,users", "tags.uid=users.uid AND users.seclev = 1 AND tagnameid in($up_id, $down_id) $d_clause");
	$data->{globjid_cnt_hour} = $slashdb->sqlSelect("count(distinct globjid)", "tags,users", "tags.uid=users.uid AND users.seclev = 1 AND tagnameid in($up_id, $down_id) $h_clause");
	slashDisplay("firehose_usage", $data, { Return => 1 });
}

sub getNextItemsForThumbnails {
	my($self, $lastid, $limit) = @_;
	$limit = " LIMIT $limit" if $limit;
	$lastid = " AND firehose.id > $lastid" if defined $lastid;
	return $self->sqlSelectAllHashrefArray("firehose.id,urls.url", "firehose,urls", "firehose.type='submission' AND firehose.url_id=urls.url_id AND mediatype='video' $lastid", "ORDER BY firehose.id ASC $limit");
}

sub createSectionSelect {
	my($self, $default) = @_;
	my $skins 	= $self->getSkins();
	my $constants 	= getCurrentStatic();
	my $user = 	getCurrentUser();
	my $ordered 	= [];
	my $menu;

	foreach my $skid (keys %$skins) {
		if ($skins->{$skid}{skid} == $constants->{mainpage_skid}) {
			$menu->{0} = $constants->{sitename};
		} else {
			$menu->{$skid} = $skins->{$skid}{title};
		}
	}
	my $onchange = $user->{is_anon} 
		? "firehose_change_section_anon(this.options[this.selectedIndex].value)" 
		: "firehose_set_options('tabsection', this.options[this.selectedIndex].value)";

	@$ordered = sort {$a == 0 ? -1 : $b == 0 ? 1 : 0 || $menu->{$a} cmp $menu->{$b} } keys %$menu;
	return createSelect("section", $menu, { default => $default, return => 1, nsort => 0, ordered => $ordered, multiple => 0, onchange => $onchange });

	
}

sub linkFireHose {
	my($self, $id_or_item) = (@_);
	my $gSkin 	= getCurrentSkin();
	my $constants 	= getCurrentStatic();
	my $link_url;
	my $item = ref($id_or_item) ? $id_or_item : $self->getFireHose($id_or_item);

	if ($item->{type} eq "story") {
		my $story = $self->getStory($item->{srcid});
		my $story_link_ar = linkStory({
			sid	=> $story->{sid},
			link 	=> $story->{title},
			tid 	=> $story->{tid},
			skin	=> $story->{primaryskid}
		}, 0);
		$link_url = $story_link_ar->[0];
	} elsif ($item->{type} eq "journal") {
		my $the_user = $self->getUser($item->{uid});
		$link_url = $constants->{rootdir} . "/~" . fixparam($the_user->{nickname}) . "/journal/$item->{srcid}"; 
	} else {
		$link_url = $gSkin->{rootdir} . '/firehose.pl?op=view&amp;id=' . $item->{id};
	}

}

sub js_anon_dump {
	my($self, $var) = @_;
	return Data::JavaScript::Anon->anon_dump($var);
}

sub genFireHoseParams {
	my($self, $options, $data) = @_;
	$data ||= {};
	my @params;

	foreach my $label (qw(fhfilter color orderdir orderby startdate duration mode)) {
	
		my $value = defined $data->{$label} ? $data->{$label} : $options->{$label};
		if ($label eq "startdate") {
			$value =~s /-//g;
		}
		push @params, "$label=$value";
		
	}

	my $str =  join('&amp;', @params);
	return $str;
}

sub createUpdateLog {
	my($self, $data) = @_;
	return if !getCurrentStatic("firehose_logging");
	$data->{uid} ||= getCurrentUser('uid');
	$self->sqlInsert("firehose_update_log", $data);
}

sub createSettingLog {
	my($self, $data) = @_;
	return if !getCurrentStatic("firehose_logging");
	return if !$data->{name};

	$data->{value} ||= "";
	$data->{uid} ||= getCurrentUser('uid');
	$self->sqlInsert("firehose_setting_log", $data);
}
1;

__END__


=head1 SEE ALSO

Slash(3).
