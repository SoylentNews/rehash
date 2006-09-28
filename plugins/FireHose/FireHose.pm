# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

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
use Slash::Tags;
use Data::JavaScript::Anon;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub createFireHose {
	my($self, $data) = @_;
	$data->{-createtime} ||= "NOW()";

	my $text_data = {};
	$text_data->{title} = delete $data->{title};
	$text_data->{introtext} = delete $data->{introtext};
	$text_data->{bodytext} = delete $data->{bodytext};

	$self->sqlInsert("firehose", $data);
	$text_data->{id} = $self->getLastInsertId({ table => 'firehose', prime => 'id' });

	my $searchtoo = getObject('Slash::SearchToo');
	if ($searchtoo) {
		$searchtoo->storeRecords(firehose => $text_data->{id}, { add => 1 });
	}

	$self->sqlInsert("firehose_text", $text_data);

}

sub createUpdateItemFromJournal {
	my($self, $id) = @_;
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $globjid_q = $self->sqlQuote($globjid);
		my($itemid) = $self->sqlSelect("*", "firehose", "globjid=$globjid_q");
		if ($itemid) {
			my $introtext = balanceTags(strip_mode($journal->{article}, $journal->{posttype}), { deep_nesting => 1 });
			$self->setFireHose($itemid, { introtext => $introtext, title => $journal->{description}, tid => $journal->{tid}});
		} else {
			$self->createItemFromJournal($id);
		}
	}
}

sub createItemFromJournal {
	my($self, $id) = @_;
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	my $introtext = balanceTags(strip_mode($journal->{article}, $journal->{posttype}), { deep_nesting => 1 });
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $data = {
			title 			=> $journal->{description},
			globjid 		=> $globjid,
			uid 			=> $journal->{uid},
			attention_needed 	=> "yes",
			public 			=> "yes",
			introtext 		=> $introtext,
			type 			=> "journal",
			popularity		=> 2,
			tid			=> $journal->{tid},
			srcid			=> $id
		};
		$self->createFireHose($data);
	}

}

sub createUpdateItemFromBookmark {
	my($self, $id, $options) = @_;
	$options ||= {};
	my $bookmark_db = getObject("Slash::Bookmark");
	my $bookmark = $bookmark_db->getBookmark($id);
	my $url_globjid = $self->getGlobjidCreate("urls", $bookmark->{url_id});
	my($count) = $self->sqlCount("firehose", "globjid=$url_globjid");
	my $popularity = defined $options->{popularity} ? $options->{popularity} : 1;
	my $activity   = defined $options->{activity}   ? $options->{activity}   : 1;

	if ($count) {
		$self->sqlUpdate("firehose", { -popularity => "popularity + 1" }, "globjid=$url_globjid");
	} else {
		my $type = $options->{type} || "bookmark";
		my $data = {
			globjid 	=> $url_globjid,
			title 		=> $bookmark->{title},
			url_id 		=> $bookmark->{url_id},
			uid 		=> $bookmark->{uid},
			popularity 	=> $popularity,
			activity 	=> $activity,
			public 		=> "yes",
			type		=> $type,
			srcid		=> $id
		};
		$self->createFireHose($data)
	}

}

sub createItemFromSubmission {
	my($self, $id) = @_;
	my $submission = $self->getSubmission($id);
	if ($submission) {
		my $globjid = $self->getGlobjidCreate("submissions", $submission->{subid});
		my $data = {
			title 			=> $submission->{subj},
			globjid 		=> $globjid,
			uid 			=> $submission->{uid},
			introtext 		=> $submission->{story},
			popularity 		=> 2,
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
			name			=> $submission->{name}
		};
		$self->createFireHose($data);
	}

}

sub getFireHoseEssentials {
	my($self, $options) = @_;
	my $user = getCurrentUser();
	$options ||= {};
	$options->{limit} ||= 50;
	$options->{orderby} ||= "createtime";
	$options->{orderdir} = uc($options->{orderdir}) eq "ASC" ? "ASC" : "DESC";
	#($user->{is_admin} && $options->{orderby} eq "createtime" ? "ASC" :"DESC");
	

	my @where;
	my $tables = "firehose";

	if ($options->{attention_needed}) {
		push @where, "attention_needed = " . $self->sqlQuote($options->{attention_needed});
	}
	if ($options->{public}) {
		push @where, "public = " . $self->sqlQuote($options->{public});
	}
	if ($options->{accepted}) {
		push @where, "accepted = " . $self->sqlQuote($options->{accepted});
	}
	if ($options->{rejected}) {
		push @where, "rejected = " . $self->sqlQuote($options->{rejected});
	}

	if ($options->{type}) {
		push @where, "type = " . $self->sqlQuote($options->{type});
	}

	if ($options->{primaryskid}) {
		push @where, "primaryskid = " . $self->sqlQuote($options->{primaryskid});
	}

	if (defined $options->{category} || $user->{is_admin}) {
		$options->{category} ||= '';
		push @where, "category = " . $self->sqlQuote($options->{category});
	}
	
	if ($options->{filter}) {
		$tables .= ",firehose_text";
		push @where, "firehose.id=firehose_text.id";
		push @where, "firehose_text.title like '%" . $options->{filter} . "%'"; 
	}

	if ($options->{createtime_gte}) {
		push @where, "createtime >= " . $self->sqlQuote($options->{createtime_gte}); 
	}
	if ($options->{last_update_gte}) {
		push @where, "last_update >= " . $self->sqlQuote($options->{last_update_gte}); 
	}

	if ($options->{ids}) {
		return [] if @{$options->{ids}} < 1;
		my $id_str = join ",", map { $self->sqlQuote($_) } @{$options->{ids}};
		push @where, "id IN ($id_str)";
	}

	if (defined $options->{daysback}) {
		push @where, "createtime >= DATE_SUB(NOW(), INTERVAL $options->{daysback} DAY)"
	}

	

	my $limit_str = "";
	my $where = (join ' AND ', @where) || "";
	my $offset = $options->{offset};
	$offset = "" if $offset !~ /^\d+$/;
	$offset = "$offset, " if $offset;
	$limit_str = "LIMIT $offset $options->{limit}" unless $options->{nolimit};
	my $other = "ORDER BY $options->{orderby} $options->{orderdir} $limit_str";
	my $hr_ar = $self->sqlSelectAllHashrefArray("firehose.*", $tables, $where, $other);

	# Add globj admin notes to the firehouse hashrefs.
	my $globjids = [ map { $_->{globjid} } @$hr_ar ];
	my $note_hr = $self->getGlobjAdminnotes($globjids);
	for my $hr (@$hr_ar) {
		$hr->{note} = $note_hr->{ $hr->{globjid} } || '';
	}

	return $hr_ar;
}

sub getFireHose {
	my($self, $id) = @_;
	# XXX cache this eventually
	my $id_q = $self->sqlQuote($id);
	my $answer = $self->sqlSelectHashref("*", "firehose", "id=$id_q");
	my $append = $self->sqlSelectHashref("*", "firehose_text", "id=$id_q");

	for my $key (keys %$append) {
		$answer->{$key} = $append->{$key};
	}

	# globj adminnotes are never the empty string, they are undef
	# instead.  Firehose notes are/were designed to never be undef,
	# the empty string instead.
	$answer->{note} = $self->getGlobjAdminnote($answer->{globjid}) || '';

	return $answer;
}

sub fetchItemText {
	my $form = getCurrentForm();
	my $firehose = getObject("Slash::FireHose");
	my $user = getCurrentUser();
	my $id = $form->{id};
	return unless $id && $firehose;
	my $item = $firehose->getFireHose($id);
	my $tags_top = $firehose->getFireHoseTagsTop($item);

	my $data = {
		item => $item,
		mode => "bodycontent",
		tags_top => $tags_top,
	};

	my $retval = slashDisplay("dispFireHose", $data, { Return => 1, Page => "firehose" });
	return $retval;
}

sub rejectItemBySubid {
	my ($self, $subid) = @_;
	if (!ref $subid) {
		$subid = [$subid];
	}
	return unless ref $subid eq "ARRAY";
	my $str;
	if (@$subid > 0 ) {
		$str = join ',', map { $self->sqlQuote($_) }  @$subid;
		$self->sqlUpdate("firehose", { rejected => 'yes' }, "type='submission' AND srcid IN ($str)");
	}
}

sub rejectItem {
	my $form = getCurrentForm();
	my $firehose = getObject("Slash::FireHose");
	my $tags = getObject("Slash::Tags");
	my $id = $form->{id};
	my $id_q = $firehose->sqlQuote($id);
	return unless $id && $firehose;
	my $item = $firehose->getFireHose($id);
	if ($item) {
		$firehose->setFireHose($id, { rejected => "yes" });
		if ($item->{type} eq "submission") {
			if ($item->{srcid}) {
				my $n_q = $firehose->sqlQuote($item->{srcid});
				my $uid = getCurrentUser('uid');
				my $rows = $firehose->sqlUpdate('submissions',
					{ del => 1 }, "subid=$n_q AND del=0"
				);
				if ($rows) {
					$firehose->setUser($uid,
						{ -deletedsubmissions => 'deletedsubmissions+1' }
					);
				}
			}
			
		}
	}
	
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

	return slashDisplay('tagsfirehosedivuser', {
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

sub ajaxFireHoseFetchNew {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $maxtime = $form->{maxtime};
	my $added = {};
	
	my $opts = $firehose->getAndSetOptions({ no_set => 1});
	$opts->{limit} = 10;
	$opts->{orderby} = 'createtime';
	$opts->{orderdir} = 'ASC';
	$opts->{createtime_gte} = $maxtime;

	my $items = $firehose->getFireHoseEssentials($opts);


	foreach my $i (@$items ) {
		$maxtime = $i->{createtime} if $i->{createtime} gt $maxtime;
		my $item = $firehose->getFireHose($i->{id});
		my $tags_top = $firehose->getFireHoseTagsTop($item);
		$added->{$i->{id}} = slashDisplay("dispFireHose", { item => $item, tags_top => $tags_top }, { Return => 1, Page => "firehose" });
	}
	
	
	return Data::JavaScript::Anon->anon_dump({
		added => $added,
		maxtime => $maxtime
	});
}

sub ajaxFireHoseCheckRemoved {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $id_str = $form->{ids};
	my @ids = grep {/^\d+$/} split (/,/, $id_str);
	my %ids = map { $_ => 1 } @ids;
	
	my $opts = $firehose->getAndSetOptions({ no_set => 1});
	$opts->{nolimit} = 1;
	$opts->{ids} = \@ids;
	my $items = $firehose->getFireHoseEssentials($opts);
	foreach (@$items) {
		delete $ids{$_->{id}};
	}
	return Data::JavaScript::Anon->anon_dump({
		removed => \%ids
	});

}

sub ajaxFireHoseGetUpdates {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $id_str = $form->{ids};
	my $update_time = $form->{updatetime};
	my @ids = grep {/^\d+$/} split (/,/, $id_str);
	my %ids = map { $_ => 1 } @ids;
	
	my $opts = $firehose->getAndSetOptions({ no_set => 1});
	$opts->{limit} = 25;
	$opts->{orderby} = 'last_update';
	$opts->{orderdir} = 'ASC';
	$opts->{last_update_gte} = $update_time;
	my $items = $firehose->getFireHoseEssentials($opts);

	my $update_new = {};
	my $html = {};
	foreach (@$items) {
		my $item = $firehose->getFireHose($_->{id});
		my $tags_top = $firehose->getFireHoseTagsTop($item);
		if(!$ids{$_->{id}}) {
			$update_new->{$_->{id}} = slashDisplay("dispFireHose", { item => $item, tags_top => $tags_top }, { Return => 1, Page => "firehose" });
			$update_time = $_->{createtime} if $_->{createtime} gt $update_time;
		} else {
			my $url 	= $slashdb->getUrl($item->{url_id});
			my $the_user  	= $slashdb->getUser($item->{uid});
			$html->{"title-$_->{id}"} = slashDisplay("formatHoseTitle", { item => $item, showtitle => 1, url => $url, the_user=> $the_user }, { Return => 1 });
			$html->{"tags-top-$_->{id}"} = slashDisplay("firehose_tags_top", { tags_top => $tags_top, id => $_->{id} }, { Return => 1 });
		}
	}
	my $data = {
		update_new => $update_new,
		update_time => $update_time
	};
	$data->{html} = $html if keys %$html;
	return Data::JavaScript::Anon->anon_dump($data);
}

sub ajaxUpDownFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $id = $form->{id};
	return unless $id;

	my $firehose = getObject('Slash::FireHose');
	my $tags = getObject('Slash::Tags');
	my $item = $firehose->getFireHose($id);
	return if !$item;

	my($dir) = $form->{dir};
	my $upvote   = $constants->{tags_upvote_tagname}   || 'nod';
	my $downvote = $constants->{tags_downvote_tagname} || 'nix';
	my $tag;
	if ($dir eq "+") {
		$tag = $upvote;
	} elsif ($dir eq "-") {
		$tag = $downvote;
	}
	return if !$tag;

	my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});
	my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $itemid, { uid => $user->{uid}});
	my @tags = sort Slash::Tags::tagnameorder map { $_->{tagname} } @$now_tags_ar;
	push @tags, $tag;
	my $tagsstring = join ' ', @tags;
	# XXX Tim, I need you to look this over. - Jamie 2006/09/19
	my $newtagspreloadtext = $tags->setTagsForGlobj($itemid, $table, $tagsstring);
	my $html  = {};
	my $value = {};
	$html->{"updown-$id"} = "Votes Saved";
	$value->{"newtags-$id"} = $newtagspreloadtext;

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
	slashDisplay('fireHoseForm', { item => $item, url => $url }, { Return => 1});	
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
	if ($item->{type} eq "submission") {
		$accepted_from_uid = $slashdb->countSubmissionsFromUID($item->{uid}, { del => 2 });
		$num_from_uid = $slashdb->countSubmissionsFromUID($item->{uid});
		$accepted_from_emaildomain = $slashdb->countSubmissionsWithEmaildomain($item->{emaildomain}, { del => 2 });
		$num_with_emaildomain = $slashdb->countSubmissionsWithEmaildomain($item->{emaildomain});
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
		accepted_from_emaildomain 	=> $accepted_from_emaildomain
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
		if ($categories{lc($_)}) {
			$data->{category} = lc($_);
		}
	}
	$self->setFireHose($id, $data) if keys %$data > 0;

}

sub setFireHose {
	my($self, $id, $data) = @_;
	return unless $id && $data;
	my $id_q = $self->sqlQuote($id);

	if (!exists($data->{last_update}) && !exists($data->{-last_update})) {
		my @non_trivial = grep {!/^(popularity|activity|toptags)$/} keys %$data;
		if (@non_trivial > 0) {
			$data->{-last_update} = 'NOW()'	
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

	return if !keys %$data;

	my $text_data = {};

	$text_data->{title} = delete $data->{title} if defined $data->{title};
	$text_data->{introtext} = delete $data->{introtext} if defined $data->{introtext};
	$text_data->{bodytext} = delete $data->{bodytext} if defined $data->{bodytext};

	$self->sqlUpdate('firehose', $data, "id=$id_q" );
	$self->sqlUpdate('firehose_text', $text_data, "id=$id_q") if keys %$text_data;

	my $searchtoo = getObject('Slash::SearchToo');
	if ($searchtoo) {
		my $status = 'changed';
# for now, no deletions ... this is what it would look like if we did!
#		$status = 'deleted' if $data->{accepted} eq 'yes' || $data->{rejected} eq 'yes';
		$searchtoo->storeRecords(firehose => $id, { $status => 1 });
	}
}

sub dispFireHose {
	my($self, $item, $options) = @_;
	$options ||= {};

	slashDisplay('dispFireHose', { item => $item, mode => $options->{mode} , tags_top => $options->{tags_top}, options => $options->{options} }, { Return => 1 });
}

sub getMemoryForItem {
	my($self, $item) = @_;
	my $user = getCurrentUser();
	$item = $self->getFireHose($item) if $item && !ref $item;
	return [] unless $item && $user->{is_admin};
	my $subnotes_ref = [];
	my $sub_memory = $self->getSubmissionMemory();
	foreach my $memory (@$sub_memory) {
		my $match = $memory->{submatch};
		
                if ($item->{email} =~ m/$match/i ||
		    $item->{name}  =~ m/$match/i ||
		    $item->{title}  =~ m/$match/i ||
		    $item->{ipid}  =~ m/$match/i ||
		    $item->{introtext} =~ m/$match/i) {
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
	my ($self, $opts) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $form 	= getCurrentForm();
	$opts 	        ||= {};
	my $options 	= {};

	my $types = { feed => 1, bookmark => 1, submission => 1, journal => 1 };
	my $modes = { full => 1, fulltitle => 1};

	my $mode = $form->{mode} || $user->{firehose_mode};
	$mode = $modes->{$mode} ? $mode : "fulltitle";
	$options->{mode} = $mode;
	
	if ($user->{is_admin} && $form->{setusermode}) {
		$self->setUser($user->{uid}, { firehose_usermode => $form->{firehose_usermode} ? 1 : "" });
	}

	if ($mode eq "full") {
		$options->{limit} = 25;
	} else {
		$options->{limit} = 50;
	}

	if ($form->{orderby}) {
		if ($form->{orderby} eq "popularity") {
			$options->{orderby} = "popularity";
		} else {
			$options->{orderby} = "createtime";
		}
		
	} else {
		$options->{orderby} = $user->{firehose_orderby} || "createtime";
	}
	
	if ($form->{orderdir}) {
		if (uc($form->{orderdir}) eq "ASC") {
			$options->{orderdir} = "ASC";
		} else {
			$options->{orderdir} = "DESC";
		}
		
	} else {
		$options->{orderdir} = $user->{firehose_orderdir} || "DESC";
	}

	my $fhfilter;


	if (defined $form->{fhfilter}) {
		$fhfilter = $form->{fhfilter};
		$options->{fhfilter} = $fhfilter;
	} else {
		$fhfilter = $user->{firehose_fhfilter};
		$options->{fhfilter} = $fhfilter;
	}

	$fhfilter =~ s/^\s+|\s+$//g;
	my @fh_ops = split(/\s+/, $fhfilter);

	my $skins = $self->getSkins();
	my %skin_names = map { $skins->{$_}{name} => $_ } keys %$skins;
	
	my %categories = map { ($_, $_) } (qw(hold quik),
		(ref $constants->{submit_categories}
			? map {lc($_)} @{$constants->{submit_categories}}
			: ()
		)
	);
	my $fh_options = {};
	foreach (@fh_ops) {
		if ($types->{$_} && !defined $fh_options->{type}) {
			$fh_options->{type} = $_;
		} elsif ($user->{is_admin} && $categories{$_} && !defined $fh_options->{category}) {
			$fh_options->{category} = $_;
		} elsif ($skin_names{$_} && !defined $fh_options->{primaryskid}) {
			$fh_options->{primaryskid} = $skin_names{$_};
		} elsif ($user->{is_admin} && $_ eq "rejected") { 
			$fh_options->{rejected} = "yes";
		} elsif ($user->{is_admin} && $_ eq "accepted") {
			$fh_options->{accepted} = "yes";
		} elsif (!defined $fh_options->{filter}) {
			# XXX Filter this
			$fh_options->{filter} = $_;
		}
	}
	foreach (keys %$fh_options) {
		$options->{$_} = $fh_options->{$_};
	}

	if (!$user->{is_anon} && !$opts->{no_set}) {
		my $data_change = {};
		foreach (keys %$options) {
			$data_change->{"firehose_$_"} = $options->{$_} if !defined $user->{"firehose_$_"} || $user->{"firehose_$_"} ne $options->{$_};
		}
		$self->setUser($user->{uid}, $data_change ) if keys %$data_change > 0;
		
	}


	if ($user->{is_admin} && $form->{setusermode}) {
		$options->{firehose_usermode} = $form->{firehose_usermode} ? 1 : "";
	}

	my $adminmode = 0;
	$adminmode = 1 if $user->{is_admin};
	if (defined $options->{firehose_usermode}) {
		$adminmode = 0 if $options->{firehose_usermode};
	} else {
		$adminmode = 0 if $user->{firehose_usermode};
	}

	
	if ($adminmode) {
		# $options->{attention_needed} = "yes";
		 $options->{accepted} = "no" if !$options->{accepted};
		 $options->{rejected} = "no" if !$options->{rejected};
	} else  {
		$options->{public} = "yes";
		$options->{daysback} = 1;
	}
	return $options;
}

sub getFireHoseTagsTop {
	my($self, $item) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $tags_top	 = [];
	push @$tags_top, ($item->{type});
	if ($user->{is_admin} && !$user->{firehose_usermode}) {
		my $cat = $item->{category} || "none";
		$cat .= ":1";
		push @$tags_top, $cat;
	}
	if ($item->{primaryskid} && $item->{primaryskid} != $constants->{mainpage_skid}) {
		my $the_skin = $self->getSkin($item->{primaryskid});
		push @$tags_top, "$the_skin->{name}:2";
	}
	if ($item->{tid}) {
		my $the_topic = $self->getTopic($item->{tid});
		push @$tags_top, "$the_topic->{keyword}:3";
	}
	return $tags_top;
}



1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
