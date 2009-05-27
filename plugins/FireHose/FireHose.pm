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
use Data::Dumper;
use Data::JavaScript::Anon;
use Date::Calc qw(Days_in_Month Add_Delta_YMD Add_Delta_DHMS);
use Digest::MD5 'md5_hex';
use POSIX qw(ceil);
use LWP::UserAgent;
use URI;
use Time::HiRes;
use File::Spec::Functions qw(catdir);
use File::Path qw(mkpath);

use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Slashboxes;
use Slash::Tags;
use Sphinx::Search 0.14;

use base 'Slash::Plugin';

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
	$data->{email} ||= '';

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

	# set topics rendered appropriately
	if ($ok) {
		if ($data->{type} eq "story") {
			my $tids = $self->sqlSelectColArrayref("tid", "story_topics_rendered", "stoid='$data->{srcid}'");
			$self->setTopicsRenderedForStory($data->{srcid}, $tids);
		} else {
			$self->setTopicsRenderedBySkidForItem($text_data->{id}, $data->{primaryskid});
		}
	}

	return $text_data->{id};
}

sub createUpdateItemFromJournal {
	my($self, $id) = @_;
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $globjid_q = $self->sqlQuote($globjid);
		my($itemid) = $self->sqlSelect("id", "firehose", "globjid=$globjid_q");
		if ($itemid) {
			my $bodytext  = $journal_db->fixJournalText($journal->{article}, $journal->{posttype}, $journal->{uid});
			my $introtext = $journal->{introtext} || $bodytext;

			$self->setFireHose($itemid, {
				introtext   => $introtext,
				bodytext    => $bodytext,
				title       => $journal->{description},
				tid         => $journal->{tid},
				discussion  => $journal->{discussion},
				word_count  => countWords($introtext)
			});
			return $itemid;
		} else {
			return $self->createItemFromJournal($id);
		}
	}
}

sub deleteHideFireHoseSection {
	my($self, $id) = @_;
	my $user = getCurrentUser();

	my $cur_section = $self->getFireHoseSection($id);
	return if $user->{is_anon} || !$cur_section;

	if ($cur_section->{uid} == $user->{uid}) {
		$self->sqlDelete("firehose_section", "fsid=$cur_section->{fsid}");
	} elsif ($cur_section->{uid} == 0) {
		$self->setFireHoseSectionPrefs($id, {
			display 	=> "no",
			section_name 	=> $cur_section->{section_name},
			section_filter 	=> $cur_section->{section_filter},
			view_id 	=> $cur_section->{view_id},
		});
	}
}

sub setFireHoseSectionPrefs {
	my($self, $id, $data) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $cur_section = $self->getFireHoseSection($id);
	return if $user->{is_anon} || !$cur_section;

	if ( $data->{section_default} ) {
		my $slashdb = getCurrentDB();
		$slashdb->setUser($user->{uid}, {firehose_default_section => $cur_section->{fsid}});
	}

	if ($cur_section->{uid} == $user->{uid}) {

		$self->sqlUpdate("firehose_section", $data, "fsid = $cur_section->{fsid}");
	} elsif ($cur_section->{uid} == 0) {
		if ($cur_section->{skid} == $constants->{mainpage_skid}) {
			$data->{section_name} = $cur_section->{section_name};
		}
		my $cur_prefs = $self->getSectionUserPrefs($cur_section->{fsid});
		if ($cur_prefs) {
			$self->sqlUpdate("firehose_section_settings", $data, "id=$cur_prefs->{id}");
		} else {
			$data->{uid} = $user->{uid};
			$data->{fsid} = $cur_section->{fsid};
			$self->sqlInsert("firehose_section_settings", $data);
		}
	}
}

sub setFireHoseViewPrefs {
	my($self, $id, $data) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	return if $user->{is_anon};
	my $uid_q = $self->sqlQuote($user->{uid});

	my $cur_view = $self->getUserViewById($id);
	return if $cur_view->{editable} eq "no";

	if ($cur_view) {
		my $cur_prefs = $self->getViewUserPrefs($cur_view->{id});
		if ($cur_prefs) {
			$self->sqlUpdate("firehose_view_settings", $data, "id=$cur_prefs->{id} AND uid=$uid_q");
		} else {
			$data->{uid} = $user->{uid};
			$data->{id} = $cur_view->{id};
			$self->sqlInsert("firehose_view_settings", $data);
		}
	}
}

sub removeUserPrefsForView {
	my($self, $id) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon};

	my $id_q = $self->sqlQuote($id);
	my $uid_q = $self->sqlQuote($user->{uid});

	$self->sqlDelete("firehose_view_settings", "id=$id_q and uid=$uid_q");
}

sub removeUserSections {
	my($self, $id) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon};

	my $uid_q = $self->sqlQuote($user->{uid});
	$self->sqlDelete("firehose_section_settings", "uid=$uid_q");
	$self->sqlDelete("firehose_section", "uid=$uid_q");
	$self->setUser($user->{uid}, { firehose_default_section => undef });
}

sub getFireHoseSectionsMenu {
	my($self, $fsid, $layout) = @_;
	my $user = getCurrentUser();
	my($uid_q) = $self->sqlQuote($user->{uid});

	$layout ||= 'yui';

	my $layout_q = $self->sqlQuote($layout);

	my $fsid_limit;
	if ($fsid) {
		my $fsid_q = $self->sqlQuote($fsid);
		$fsid_limit = " AND firehose_section.fsid=$fsid_q ";
	}

	my $css = $self->sqlSelectAllHashrefArray(
		"css.*, skins.name as skin_name, fsid",
		"css, skins, firehose_section",
		"css.skin=skins.name and css.layout=$layout_q and admin='no' AND skins.skid=firehose_section.skid AND firehose_section.uid=0"
	);

	my $css_hr = {};

	foreach (@$css) {
		push @{$css_hr->{$_->{fsid}}}, $_;
	}

	my $sections = $self->sqlSelectAllHashrefArray(
		"firehose_section.*, firehose_section_settings.display AS user_display, firehose_section_settings.section_name as user_section_name, firehose_section_settings.section_filter AS user_section_filter, firehose_section_settings.view_id AS user_view_id, firehose_section_settings.section_color AS user_section_color",
		"firehose_section LEFT JOIN firehose_section_settings on firehose_section.fsid=firehose_section_settings.fsid AND firehose_section_settings.uid=$uid_q",
		"firehose_section.uid in (0,$uid_q) $fsid_limit",
		"ORDER BY uid, ordernum, section_name"
	);

	foreach (@$sections) {
		$_->{data}{id} 		= $_->{fsid};
		$_->{data}{name} 	= $_->{user_section_name} ? $_->{user_section_name} : $_->{section_name};
		$_->{data}{filter}	= $_->{user_section_filter} ? $_->{user_section_filter} : $_->{section_filter};
		my $viewid  		= $_->{user_view_id} ? $_->{user_view_id} : $_->{view_id};

		my $view = $self->getUserViewById($viewid);
		my $viewname = $view->{viewname} || "stories";

		$_->{data}{viewname} 	= $viewname;
		$_->{data}{color}	= $_->{user_section_color} ? $_->{user_section_color} : $_->{section_color};

		if ( $_->{skid} && ((!$_->{user_section_filter}) || ($_->{section_filter} eq $_->{user_section_filter})) ) {
			if ($css_hr->{$_->{fsid}}) {
				foreach my $css(@{$css_hr->{$_->{fsid}}}) {
					$_->{data}{skin} .= getData('alternate_section_stylesheet', { css => $css, }, 'firehose');
				}
			}
		}
	}

	if (!$user->{firehose_section_order}) {
		return $sections;
	} else {
		my %sections_hash = map { $_->{fsid}  => $_ } @$sections;
		my @ordered_sections;
		foreach (split /,/, $user->{firehose_section_order}) {
			if ($sections_hash{$_}) {
				push @ordered_sections, delete $sections_hash{$_};
			}
		}

		foreach (@$sections) {
			push @ordered_sections, $_ if $sections_hash{$_->{fsid}}
		}
		return \@ordered_sections;
	}
}

sub createFireHoseSection {
	my($self, $data) = @_;
	$self->sqlInsert("firehose_section", $data);
	return $self->getLastInsertId({ table => 'firehose_section', prime => 'fsid' });
}

sub ajaxSaveFireHoseSections {
	my($slashdb, $constants, $user, $form, $options) = @_;
	return if $user->{is_anon};
	$slashdb->setUser($user->{uid}, {firehose_section_order => $form->{fsids}});
}

sub ajaxSaveHideSectionMenu {
	my($slashdb, $constants, $user, $form, $options) = @_;
	return if $user->{is_anon};
	my $hide = $form->{hide_section_menu} && ($form->{hide_section_menu} ne 'false');
	$slashdb->setUser($user->{uid}, {firehose_hide_section_menu => $hide});
}

sub ajaxSetFireHoseDefaultSection {
	my($slashdb, $constants, $user, $form, $options) = @_;
	return if $user->{is_anon};
	$slashdb->setUser($user->{uid}, {firehose_default_section => $form->{default_section}});
}

sub ajaxDeleteFireHoseSection {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $fh = getObject("Slash::FireHose");
	if ($form->{id}) {
		if ($form->{undo}) {
			$fh->setFireHoseSectionPrefs($form->{id}, { display => "yes" });
		} else {
			$fh->deleteHideFireHoseSection($form->{id});
		}
	}
}

sub ajaxNewFireHoseSection {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $fh = getObject("Slash::FireHose");
	return if $user->{is_anon};
	my $data = {
		section_name	=> $form->{name},
		section_color	=> $form->{color},
		section_filter	=> $form->{fhfilter},
		uid		=> $user->{uid},
		view_id		=> $form->{view_id}||0
	};

	my $fsid = $fh->createFireHoseSection($data);

	my $data_dump = {};

	if ($fsid) {
		if ( $data->{as_default} ) {
			$slashdb->setUser($user->{uid}, {firehose_default_section => $fsid});
		}

		my $res = $fh->getFireHoseSectionsMenu($fsid);
		my $fh_section = $res->[0];

		$data_dump =  Data::JavaScript::Anon->anon_dump({
			id 	=> $fsid,
			li	=> getData('newsectionli', { id => $fsid, name => $form->{name}, fh_section => $fh_section }, 'firehose')
		});
	}
	return $data_dump;
}

sub getSectionSkidFromFilter {
	my($self, $filter) = @_;
	my $got_section = 0;

	foreach (split(/\s+/, $filter)) {
		last if $got_section;
		my $cur_skin = $self->getSkin($_);
		if ($cur_skin) {
			$got_section = $cur_skin->{skid};
		}
	}
	return $got_section;
}

sub getCSSForSkid {
	my($self,$skid,$layout) = @_;
	my $form = getCurrentForm();
	my $secure = apacheConnectionSSL();

	$layout = defined $layout ? $layout:
		defined $form->{layout} ? $form->{layout} : "yui";

	my $layout_q = $self->sqlQuote($layout);

	my $css = [];
	if ($skid) {
		my $skid_q = $self->sqlQuote($skid);
		$css = $self->sqlSelectAllHashrefArray(
			"css.*, skins.name as skin_name",
			"css, skins",
			"css.skin=skins.name and css.layout=$layout_q and admin='no' AND skins.skid=$skid_q"
		);
	}

	my $retval = "";
	my $skin_name = "";
	foreach (@$css) {
		$skin_name = $_->{skin_name};
		$_->{file} =~ s/\.css/.ssl.css/ if $secure;
		$retval .= getData('alternate_section_stylesheet', { css => $_, }, 'firehose');
	}
	return $retval;
}

sub ajaxFireHoseSectionCSS {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $fh = getObject("Slash::FireHose");
	my $section = $fh->getFireHoseSection($form->{section});
	my $got_section = 0;

	if ($section && $section->{fsid}) {
		$got_section = $fh->getSectionSkidFromFilter($section->{section_filter});
	}

	my $retval = $fh->getCSSForSkid($got_section, $form->{layout});
	my $skin_name;
	my $skin = $slashdb->getSkin($got_section);
	$skin_name = $skin->{name};
	my $data_dump =  Data::JavaScript::Anon->anon_dump({
		skin_name 		=> $skin_name,
		css_includes 		=> $retval,
	});

	return $data_dump;
}

sub ajaxTogglePickerSearch {
	my($slashdb, $constants, $user, $form, $options) = @_;
	return if $user->{is_anon};
	$slashdb->setUser($user->{uid}, {firehose_disable_picker_search => undef});
}

sub ajaxToggleSmallScreen {
	my($slashdb, $constants, $user, $form, $options) = @_;
	return if $user->{is_anon};

	my $prefs = {
		smallscreen => undef,
		firehose_noslashboxes => undef,
		firehose_hide_section_menu => undef,
		disable_ua_check       => 1,
	};
	$slashdb->setUser($user->{uid}, $prefs);
}

sub ajaxToggleSimpleDesign {
	my($slashdb, $constants, $user, $form, $options) = @_;
	return if $user->{is_anon};

	my $prefs = {
		simpledesign => undef,
		firehose_noslashboxes => undef,
		firehose_hide_section_menu => undef,
		firehose_nographics => undef,
	};
	$slashdb->setUser($user->{uid}, $prefs);
}

sub getFireHoseSectionBySkid {
	my($self, $skid) = @_;
	my $skid_q = $self->sqlQuote($skid);
	return $self->sqlSelectHashref("*", "firehose_section","uid=0 AND skid=$skid_q");
}

sub getFireHoseSection {
	my($self, $fsid) = @_;

	my $user = getCurrentUser();
	my $uid_q = $self->sqlQuote($user->{uid});
	my $fsid_q = $self->sqlQuote($fsid);

	return $self->sqlSelectHashref("*","firehose_section","uid in(0,$uid_q) AND fsid=$fsid_q");
}

sub getSectionUserPrefs {
	my($self, $fsid) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon};
	my $fsid_q = $self->sqlQuote($fsid);
	my $uid_q = $self->sqlQuote($user->{uid});
	return $self->sqlSelectHashref("*", "firehose_section_settings", "uid=$uid_q AND fsid=$fsid_q");
}

sub getViewUserPrefs {
	my($self, $id) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon};
	my $id_q = $self->sqlQuote($id);
	my $uid_q = $self->sqlQuote($user->{uid});
	return $self->sqlSelectHashref("*", "firehose_view_settings", "uid=$uid_q AND id=$id_q");
}

{
my $constants = getCurrentStatic();
my $color_str = $constants->{firehose_color_labels} || '';
my $color_a = [ split(/\|/, $color_str) ];
my $color_h = {};
my $i = 0;
$color_h->{$_} = ++$i for @$color_a;

sub getFireHoseColors {
	my($self, $array) = @_;
	return $color_a if $array;
	return $color_h;
}

sub getFireHoseColor {
	my($self, $color) = @_;
	if ($color =~ /\D/) {
		return $color_h->{$color} || scalar @$color_a;
	} else {
		my $i = $color-1;
		$i = 0 if $i < 0;
		return $color_a->[$i] || $color_a->[-1];
	}
}

sub getFireHoseColorDelta {
	my($self, $start, $delta) = @_;
	my $color = $start =~ /\D/ ? $self->getFireHoseColor($start) : $start;

	my $i = ($color-1) + $delta;
	$i = 0 if $i < 0;
	return $color_a->[$i] || $color_a->[-1];
}
}

sub createUpdateItemFromComment {
	my($self, $cid) = @_;
	my $comment = $self->getComment($cid);
	my $text = $self->getCommentText($cid);

	my $item = $self->getFireHoseByTypeSrcid("comment", $cid);
	my $fhid;

	if ($item && $item->{id}) {
		# update item or do nothing
		$fhid = $item->{id};
	} else {
		$fhid = $self->createItemFromComment($cid);
	}
	return $fhid;
}

sub createItemFromComment {
	my($self, $cid) = @_;
	my $comment = $self->getComment($cid);
	my $text = $self->getCommentText($cid);
	my $globjid = $self->getGlobjidCreate("comments", $cid);

	# Set initial popularity scores -- we'll be forcing a quick
	# recalculation of them so these scores don't much matter.
	my($popularity, $editorpop, $neediness);
	$popularity = $self->getEntryPopularityForColorLevel(7);
	$editorpop = $self->getEntryPopularityForColorLevel(7);
	$neediness = $self->getEntryPopularityForColorLevel(6);

	my $data = {
		uid		=> $comment->{uid},
		public		=> "yes",
		title		=> $comment->{subject},
		introtext	=> $text,
		ipid		=> $comment->{ipid},
		subnetid 	=> $comment->{subnetid},
		type		=> "comment",
		srcid		=> $comment->{cid},
		popularity	=> $popularity,
		editorpop	=> $editorpop,
		globjid		=> $globjid,
		discussion	=> $comment->{sid},
		createtime	=> $comment->{date},
	};
	my $fhid = $self->createFireHose($data);

	if (!isAnon($comment->{uid})) {
		my $constants = getCurrentStatic();
		my $tags = getObject('Slash::Tags');
		$tags->createTag({
			uid			=> $comment->{uid},
			name			=> $constants->{tags_upvote_tagname},
			globjid			=> $globjid,
			private			=> 1,
		});
	}

	my $tagboxdb = getObject('Slash::Tagbox');
	if ($tagboxdb) {
		for my $tbname (qw( FireHoseScores FHEditorPop CommentScoreReason )) {
			my $tagbox = $tagboxdb->getTagboxes($tbname);
			next unless $tagbox;
			$tagbox->{object}->forceFeederRecalc($globjid);
		}
	}

	return $fhid;
}


sub createItemFromJournal {
	my($self, $id) = @_;
	my $user = getCurrentUser();
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	my $bodytext  = $journal_db->fixJournalText($journal->{article}, $journal->{posttype}, $journal->{uid});
	my $introtext = $journal->{introtext} || $bodytext;
	if ($journal) {
		my $constants = getCurrentStatic();
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});

		my $publicize  = $journal->{promotetype} eq 'publicize';
		my $publish    = $journal->{promotetype} eq 'publish';
		my $color_lvl  = $publicize ? 5 : $publish ? 6 : 7; # post == 7
		my $editor_lvl = $publicize ? 5 : $publish ? 6 : 8; # post == 8
		my $public     = 'yes';
		my $popularity = $self->getEntryPopularityForColorLevel($color_lvl);
		my $editorpop  = $self->getEntryPopularityForColorLevel($editor_lvl);

		my $type = $user->{acl}{vendor} ? "vendor" : "journal";

		my $data = {
			title                   => $journal->{description},
			globjid                 => $globjid,
			uid                     => $journal->{uid},
			attention_needed        => "yes",
			public                  => $public,
			introtext               => $introtext,
			bodytext		=> $bodytext,
			popularity              => $popularity,
			editorpop               => $editorpop,
			tid                     => $journal->{tid},
			srcid                   => $id,
			discussion              => $journal->{discussion},
			type                    => $type,
			ipid                    => $user->{ipid},
			subnetid                => $user->{subnetid},
			createtime              => $journal->{date}
		};

		my $id = $self->createFireHose($data);

		my $tags = getObject('Slash::Tags');
		$tags->createTag({
			uid             => $journal->{uid},
			name            => $constants->{tags_upvote_tagname},
			globjid         => $globjid,
			private         => 1,
		});

		return $id;
	}
}

sub getUserBookmarkForUrl {
	my($self, $uid, $url_id) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $url_id_q = $self->sqlQuote($url_id);
	return $self->sqlSelectHashref("*", "bookmarks", "uid=$uid_q and url_id=$url_id_q");
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
	my $firehose_id;
	my $popularity = undef;
	$popularity = $options->{popularity} if defined $options->{popularity};
	if (!defined $popularity) {
		my $cl = 7;
		my $wanted = $constants->{postedout_wanted} || 2;
		if ($type eq 'feed' && $self->countStoriesPostedOut() < $wanted) {
			# If there aren't "enough" posted-out stories and
			# this bookmark is a feed item, it gets bumped up
			# one color level.
			$cl = 6;
		}
		$popularity = $self->getEntryPopularityForColorLevel($cl);
	}

	my $activity = defined $options->{activity} ? $options->{activity} : 1;

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
			srcid		=> $id,
			createtime	=> $bookmark->{createdtime},
		};
		$data->{introtext} = $options->{introtext} if $options->{introtext};
		if ($type eq "feed") {
			my $feed = $bookmark_db->getBookmarkFeedByUid($bookmark->{uid});
			if ($feed && $feed->{feedname}) {
				$data->{srcname} = $feed->{feedname};
			}
		}
		$firehose_id = $self->createFireHose($data);
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

		if (!isAnon($bookmark->{uid}) && !$options->{no_nod}) {
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
	return $firehose_id;
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

sub createItemFromProject {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	my $proj = $self->getProject($id);
	my $globjid = $self->getGlobjidCreate("projects", $proj->{id});
	my $midpop = $self->getEntryPopularityForColorLevel(5);

	my $data = {
		uid		=> $proj->{uid},
		title		=> $proj->{textname},
		srcid		=> $proj->{id},
		type		=> "project",
		url_id		=> $proj->{url_id},
		globjid		=> $globjid,
		srcname		=> $proj->{srcname},
		introtext 	=> $proj->{description},
		public		=> "yes",
		editorpop	=> $midpop,
		popularity	=> $midpop,
		createtime	=> $proj->{createtime}
	};
	my $firehose_id = $self->createFireHose($data);
	my $discussion_id = $self->createDiscussion({
		uid		=> 0,
		kind		=> 'project',
		title		=> $proj->{textname},
		commentstatus	=> 'logged_in',
		url		=> "$constants->{rootdir}/firehose.pl?op=view&id=$firehose_id"
	});

	if ($discussion_id) {
		$self->setFireHose($firehose_id, {
			discussion	=> $discussion_id,
		});
	}
	return $firehose_id;
}

sub updateItemFromProject {
	my($self, $id);
	my $proj = $self->getProject($id);
	if ($proj && $proj->{id}) {
		my $item = $self->getFireHoseByTypeSrcid("project", $proj->{id});
		if ($item && $item->{id}) {
			my $data = {
				uid		=> $proj->{uid},
				url_id		=> $proj->{url_id},
				title 		=> $proj->{textname},
				introtext 	=> $proj->{description},
				createtime	=> $proj->{createtime}
			};
			$self->setFireHose($item->{id}, $data);
		}
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
			$data->{offmainpage} = "no";
			$data->{offmainpage} = "yes" if defined $story->{offmainpage} && $story->{offmainpage};

			if (defined $story->{mediatype}) {
				if (!$story->{mediatype}) {
					$data->{mediatype} = "none";
				} else {
					$data->{mediatype} = $story->{mediatype};
				}
			}
			$self->setFireHose($id, $data);
		}
	}
}

sub setTopicsRenderedBySkidForItem {
	my($self, $id, $primaryskid) = @_;
	my $constants = getCurrentStatic();
	my $skin = $self->getSkin($primaryskid);

	# if no primaryskid assign to mainpage skid
	my $nexus = $skin && $skin->{nexus} ? $skin->{nexus} : $constants->{mainpage_nexus_tid};

	$self->sqlDelete("firehose_topics_rendered", "id = $id");
	$self->sqlInsert("firehose_topics_rendered", { id => $id, tid => $nexus });
	$self->setFireHose($id, { nexuslist => " $nexus " });
}

sub setTopicsRenderedForStory {
	my($self, $stoid, $tids) = @_;
	my $the_tids = [ @$tids ]; # Copy tids so any changes we make don't affect the caller
	my $constants = getCurrentStatic();
	my $story = $self->getStory($stoid, "", 1);
	if ($story) {
		my $globjid = $self->getGlobjidCreate("stories", $story->{stoid});
		my $id = $self->getFireHoseIdFromGlobjid($globjid);
		my @nexus_topics;
		if ($id) {
			$self->sqlDelete("firehose_topics_rendered", "id = $id");
			foreach (@$the_tids) {
				$self->sqlInsert("firehose_topics_rendered", { id => $id, tid => $_});
			}
			my $tree = $self->getTopicTree();
			@nexus_topics = grep { $tree->{$_}->{nexus} } @$the_tids;
			my $nexus_list = join ' ', @nexus_topics;
			$nexus_list = " $nexus_list ";
			$self->setFireHose($id, { nexuslist => $nexus_list });
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

		$data->{offmainpage} = "no";
		$data->{offmainpage} = "yes" if defined $story->{offmainpage} && $story->{offmainpage};

		if (defined $story->{mediatype}) {
			if (!$story->{mediatype}) {
				$data->{mediatype} = "none";
			} else {
				$data->{mediatype} = $story->{mediatype};
			}
		}
		$self->createFireHose($data);
	}
}

sub getFireHoseCount {
	my($self) = @_;
	my $pop = $self->getEntryPopularityForColorLevel(6);

	#XXXFH - add time limit later?
	return $self->sqlCount("firehose",
		"editorpop >= $pop AND rejected='no' AND accepted='no' AND type != 'story'");
}

{
my %cat_types = ('', 0, 'back', 1, 'hold', 2, 'quik', 3);

my %gtid_types = (
	story      => 1,
	submission => 3,
	journal    => 4,
	comment    => 5,
	discussion => 7,
	project    => 11,
	bookmark   => 12,
	feed       => 13,
	vendor     => 14,
	misc       => 15,
);

my %sphinx_orderby = (
	createtime => 'createtime_ut',
	popularity => 'popularity',
	editorpop  => 'editorpop',
	neediness  => 'neediness'
);

# SPH_SORT_RELEVANCE ATTR_DESC ATTR_ASC TIME_SEGMENTS EXTENDED EXPR
my %sphinx_orderdir = (
	ASC        => SPH_SORT_ATTR_ASC,
	DESC       => SPH_SORT_ATTR_DESC
);

# SPH_MATCH_ALL ANY PHRASE BOOLEAN EXTENDED2
my %sphinx_mode = (
	all        => SPH_MATCH_ALL,
	any        => SPH_MATCH_ANY,
	boolean    => SPH_MATCH_BOOLEAN,
	extended2  => SPH_MATCH_EXTENDED2
);

# This method will allow multiple search paths to be followed, for merging
# back together later.  ** DO NOT ** use this unless you really know what
# you're doing.  Srsly.  For every set of params you push on here, you
# *multiply*, not *add" to, the number of queries needed.  -- pudge
sub getFireHoseEssentialsPushMulti {
	my($multi, $new) = @_;

	return unless ref($multi) && ref($new);
	return unless @$new;

	if (!@$multi) {
		# deepcopy
		for (@$new) { push @$multi, [ @$_ ] }
		return;
	}

	my $tmp = [];
	for my $mar (@$multi) {
		for my $nar (@$new) {
			push @$tmp, [ @$mar, @$nar ];
		}
	}

	@$multi = @$tmp;
}

sub getFireHoseEssentialsParams {
	my($self, $options, $sphinx) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my(@sphinx_opts, @sphinx_opts_multi, @sphinx_terms, @sphinx_where);
	my @sphinx_tables = ('sphinx_search');

	my $cur_time = $self->getTime({ unix_format => 1 });

	my $tags = getObject('Slash::Tags');
	my $need_tagged = 0;
	$need_tagged = 1 if $options->{tagged_by_uid} && $options->{tagged_as};
	$need_tagged = 2 if $options->{tagged_by_uid} && $options->{tagged_non_negative};
	$need_tagged = 3 if $options->{tagged_by_uid} && $options->{tagged_for_homepage};

	if ($need_tagged) {
		my $tagged_by_uid = $options->{tagged_by_uid};
		@$tagged_by_uid = grep $_ && !/\D/, @$tagged_by_uid;

		if ($need_tagged == 1) {
			# This combination of options means to restrict to only
			# those hose entries tagged by one particular user with
			# one particular tag, e.g. /~foo/tags/bar
			push @sphinx_tables, 'tags';
			# note: see below, where this clause can be manipulated for $sph
			push @sphinx_where, 'tags.globjid = sphinx_search.globjid';
			my $tag_id = $tags->getTagnameidFromNameIfExists($options->{tagged_as}) || 0;
			push @sphinx_where, "tags.tagnameid = $tag_id";
			push @sphinx_where, "tags.uid = $tagged_by_uid";
			$sphinx->{check_sql} = 1;
			push @sphinx_opts, [ filter => tfh => $tagged_by_uid ];
		} elsif ($need_tagged == 2) {
			# This combination of options means to restrict to only
			# those hose entries tagged by one particular user with
			# any "tagged for hose" tags (/~foo/firehose).
			push @sphinx_opts, [ filter => tfh => $tagged_by_uid ];
		} elsif ($need_tagged == 3) {
			# This combination of options means to restrict to only
			# those hose entries tagged by one particular user with
			# any "tagged for homepage" tags (/~foo).
			push @sphinx_opts, [ filter => tfhp => $tagged_by_uid ];
		}
		push @sphinx_where, 'inactivated IS NULL';
	}
	if ($options->{startdateraw}) {
		my $st_sphinx = timeCalc($options->{startdateraw}, '%s',0);
		if ($options->{orderby} eq "ASC") {
			push @sphinx_opts, [ range => createtime_ut => 0, $st_sphinx, 1 ];
		} else {
			push @sphinx_opts, [ range => createtime_ut => 0, $st_sphinx ];
		}
	} elsif ($options->{startdate}) {
		my $startdate = $options->{startdate};

		my($db_levels, $db_order) = getDayBreakLevels();
		my $level = parseDayBreakLevel($startdate) || 'day';
		my @arr = $startdate =~ $db_levels->{$level}{re};
		$startdate = $db_levels->{$level}{timefmt}->(@arr);

		$startdate = $options->{startdate} if $options->{spritegen};

		my $st_sphinx  = timeCalc($startdate, '%s', -$user->{off_set});

		if (defined $options->{duration} && $options->{duration} >= 0) {
			my $dur_q = $self->sqlQuote($options->{duration});
			my $enddate = $self->getDayFromDay($options->{startdate}, -$options->{duration}); # minus means add here
			my @arr = $enddate =~ $db_levels->{$level}{re};
			$enddate = $db_levels->{$level}{timefmt}->(@arr);

			my $end_sphinx  = timeCalc($enddate, '%s', -$user->{off_set});
			push @sphinx_opts, [ range => createtime_ut => $st_sphinx, $end_sphinx ];

		} elsif ($options->{duration} == -1) {
			if ($options->{orderdir} eq "ASC") {
				# ! is for negating, since this is >, not <
				my $time = $st_sphinx-1;
				push @sphinx_opts, [ range => createtime_ut => 0, $time, 1 ];

			} else {
				my $enddate = $self->getDayFromDay($options->{startdate}, -1); # add one
				my @arr = $enddate =~ $db_levels->{$level}{re};
				$enddate = $db_levels->{$level}{timefmt}->(@arr);
				@arr = $enddate =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
				$enddate = sprintf "%04d-%02d-%02d %02d:%02d:%02d", Add_Delta_DHMS(@arr, 0, 0, 0, -1);

				my $end_sphinx = timeCalc($enddate, '%s', -$user->{off_set});
				push @sphinx_opts, [ range => createtime_ut => 0, $end_sphinx ];
			}
		}

	} elsif (defined $options->{duration} && $options->{duration} >= 0) {
		my $dur_sphinx = $options->{duration} * 86400;
		my $dur_time = ($cur_time - $dur_sphinx) - 1;
		push @sphinx_opts, [ range => createtime_ut => 0, $dur_time, 1 ];
	}

	if ($user->{is_admin} || $user->{acl}{signoff_allowed}) {
		$sphinx->{no_mcd} = 1;

		if ($options->{unsigned}) {
			push @sphinx_opts, [ filter => signoff => [ $user->{uid} ], 1 ];

			my $days_relevant = 30;
			my $time_back = $cur_time - (86400 * $days_relevant);

# 			if ((!$options->{type} || $options->{type} eq 'story') && (!$options->{not_type} || $options->{not_type} ne 'story')) {
# 				push @sphinx_opts, [ range => createtime_ut => 0, $time_back, 1 ];
# 			}

			# SSS sample pseudocode for multi
			my $time_filter = [ range => createtime_ut => 0, $time_back, 1 ];
			if (!$options->{type} && (!$options->{not_type} || $options->{not_type} ne 'story')) {
				getFireHoseEssentialsPushMulti(\@sphinx_opts_multi, [[
					[ filter => gtid => [$gtid_types{story}] ],
					$time_filter
				], [
					[ filter => gtid => [$gtid_types{story}], 1 ],
				]]);
			} elsif ($options->{type} eq 'story') {
				push @sphinx_opts, $time_filter;
			}

		} elsif ($options->{signed}) {
			push @sphinx_opts, [ filter => signoff => [ $user->{uid} ] ];
		}
	}

	if ($options->{createtime_no_future}) {
		push @sphinx_opts, [ range => createtime_ut => 0, $cur_time ];
	}

	if ($options->{createtime_subscriber_future}) {
		my $future_secs = $constants->{subscribe_future_secs};
		my $future_time = $cur_time + $future_secs;
		push @sphinx_opts, [ range => createtime_ut => 0, $future_time ];
	}

	if ($options->{offmainpage}) {
		my $off = $options->{offmainpage} eq 'yes' ? 1 : 0;
		push @sphinx_opts, [ filter => offmainpage => [ $off ] ];
	}

	if ($options->{public}) {
		my $pub = $options->{public} eq 'yes' ? 1 : 0;
		push @sphinx_opts, [ filter => public => [ $pub ] ];
	}

	if ($options->{nexus}) {
		push @sphinx_opts, [ filter => tid => $options->{nexus} ];
	}

	if ($options->{not_nexus}) {
		push @sphinx_opts, [ filter => tid => $options->{not_nexus}, 1 ];
	}

	if ($options->{attention_needed}) {
		my $needed = $options->{attention_needed} eq 'yes' ? 1 : 0;
		push @sphinx_opts, [ filter => attention_needed => [ $needed ] ];
	}

	if ($options->{accepted}) {
		my $accepted = $options->{accepted} eq 'yes' ? 1 : 0;
		push @sphinx_opts, [ filter => accepted => [ $accepted ] ];
	}

	if ($options->{rejected}) {
		my $rejected = $options->{rejected} eq 'yes' ? 1 : 0;
		push @sphinx_opts, [ filter => rejected => [ $rejected ] ];
	}

	if ($options->{'pop'}) {
		my $field = $user->{is_admin} && !$options->{usermode} ? 'editorpop' : 'popularity';
		# in sphinx index, popularity has 1000000 added to it
		my $max = int($options->{'pop'}) + 1_000_000 - 1;
		push @sphinx_opts, [ range => $field => 0, $max, 1 ];
	}

	if (defined $options->{category} || ($user->{is_admin} && $options->{admin_filters})) {
		$options->{category} ||= '';
		my $val = $cat_types{lc $options->{category}};
		$val = 9999 unless defined $val;
		push @sphinx_opts, [ filter => category => [ $val ] ];
	}

	foreach my $prefix ("","not_") {
		foreach my $base qw(primaryskid uid type) {
			if ($options->{"$prefix$base"}) {
				my $not = $prefix eq "not_" ? 1 : 0;
				my $cur_opt = $options->{"$prefix$base"};
				$cur_opt = [$cur_opt] if !ref $cur_opt;

				# not sure if OK to manipulate $cur_opt, so we copy -- pudge
				my $newbase = $base;
				my @new_opt = @$cur_opt;
				if ($base eq 'type') {
					$_ = $gtid_types{$_} || 9999 for @new_opt;
					$newbase = 'gtid';
				}
				push @sphinx_opts, [ filter => $newbase => \@new_opt, ($not ? 1 : 0) ];
			}
		}
	}


	if ($options->{not_id}) {
		my $globjid = $self->getFireHose($options->{not_id})->{globjid};
		push @sphinx_opts, [ filter => globjidattr => [ $globjid ], 1 ];
	}

	if ($options->{filter}) {
		if ($options->{filter}) {
			my $query;
			$sphinx->{mode} = $constants->{sphinx_match_mode} || 'boolean';
			($query, $sphinx->{mode}) = sphinxFilterQuery($options->{filter}, $sphinx->{mode});
			push @sphinx_terms, $query;
		}
	}

	return(\@sphinx_opts, \@sphinx_opts_multi, \@sphinx_terms, \@sphinx_where, \@sphinx_tables);
}


sub getFireHoseEssentials {
	my($self, $options) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();



	# SEARCH SETUP
	my($sphinx_debug, $sphinx_other) = (0, 0);
	my $sphinx = {
		no_mcd    => $user->{is_admin} && !$options->{usermode} ? 1 : 0,
		check_sql => 0,
		mode      => ''
	};


	my $sphinxdb = getObject('Slash::Sphinx', { db_type => 'sphinx', timeout => 2 });
	my $sph = Sphinx::Search->new;
	my $vu = DBIx::Password::getVirtualUser( $sphinxdb->{virtual_user} );
	my $host = $constants->{sphinx_01_hostname_searchd} || $vu->{host};
	my $port = $constants->{sphinx_01_port} || 3312;
	$sph->SetServer($host, $port);
	$sph->SetConnectTimeout(5);

	if ($sphinx_debug) {
		use Data::Dumper; local $Data::Dumper::Indent = 0; local $Data::Dumper::Sortkeys = 1;
		print STDERR "sphinx/gFHE option dump: ", Dumper($options), "\n";
	}



	# SEARCH OPTION SETUP
	my($items, $results) = ([], {});

	my $colors = $self->getFireHoseColors();
	$options ||= {};
	$options->{limit} ||= 50;
	my $page_size = $options->{limit} || 1;

	my $fetch_extra = 0;
	my($day_num, $day_label, $day_count);

	$options->{limit} += $options->{more_num} if $options->{more_num};

	my $qoptions = {};
	$qoptions->{fetch_size} = $options->{limit};
	if ($options->{orderby} && $options->{orderby} eq "createtime" && $options->{duration} != -1) {
		$fetch_extra = 1;
		$qoptions->{fetch_size}++;
	}

	$options->{'pop'} = $self->getMinPopularityForColorLevel($colors->{$options->{color}})
		if $options->{color} && $colors->{$options->{color}};

	$options->{orderby} ||= 'createtime';
	$options->{orderdir} = uc($options->{orderdir}) eq 'ASC' ? 'ASC' : 'DESC';



	# SEARCH PARAM SETUP
	my($sphinx_opts, $sphinx_opts_multi, $sphinx_terms, $sphinx_where, $sphinx_tables) = $self->getFireHoseEssentialsParams($options, $sphinx);
#use Data::Dumper; print STDERR Dumper [$sphinx_opts, $sphinx_opts_multi, $sphinx_terms, $sphinx_where, $sphinx_tables];


	# CACHE CHECK
	my($sphinx_ar, $sphinx_stats) = ([], {});

	my $mcd = $self->getMCD;
	my($mcdkey_data, $mcdkey_stats);
	# ignore memcached if admin, or if usermode is on
	if ($mcd && !$sphinx->{no_mcd}) {
		my $serial = $self->serializeOptions($options, $user);
		my $id = md5_hex($serial);

		$mcdkey_data  = "$self->{_mcd_keyprefix}:gfhe_sphinx:$id";
		$mcdkey_stats = "$self->{_mcd_keyprefix}:gfhe_sphinxstats:$id";
		$sphinx_ar    = $mcd->get($mcdkey_data);
		$sphinx_stats = $mcd->get($mcdkey_stats);
		if ($sphinx_debug) {
			my $arhit = defined($sphinx_ar)    ? 'HIT' : '';
			my $sthit = defined($sphinx_stats) ? 'HIT' : '';
			my $scnt  = defined($sphinx_ar)    ? scalar(@$sphinx_ar) : 0;
			print STDERR scalar(gmtime) . " gFHE mcd $0 '$arhit' '$sthit' $scnt $id $serial\n";
		}
		$sphinx_ar    ||= [];
		$sphinx_stats ||= {};
	}



	# QUERY OPTION SETUP
	$qoptions->{offset_num} = defined $options->{offset} ? $options->{offset} : '';
	$qoptions->{offset_num} = '' if $qoptions->{offset_num} !~ /^\d+$/;

	$qoptions->{orderby}  = $sphinx_orderby{$options->{orderby}}   || 'createtime_ut';
	$qoptions->{orderdir} = $sphinx_orderdir{$options->{orderdir}} || SPH_SORT_ATTR_DESC;
	$sph->SetSortMode($qoptions->{orderdir}, $qoptions->{orderby});
	$sph->SetMatchMode($sphinx_mode{$sphinx->{mode}} || SPH_MATCH_ALL) if $sphinx->{mode};

	$qoptions->{maxmatches} = 0;
	# in both these cases, we need to do a secondary filter run, so we are
	# getting a large number from the initial query(ies), and then getting
	# the smaller number from a MySQL query
	if (@$sphinx_tables > 1 || @$sphinx_opts_multi) {
		my $offset = length $qoptions->{offset_num} ? "$qoptions->{offset_num}, " : '';
		$sphinx_other = "LIMIT $offset$qoptions->{fetch_size}";

		$qoptions->{maxmatches} = $constants->{sphinx_01_max_matches} || 10000;
		$sph->SetLimits(0, $qoptions->{maxmatches}, $qoptions->{maxmatches});
	} else {
		$qoptions->{maxmatches} = $qoptions->{fetch_size} > 1000 ? $qoptions->{fetch_size} : undef; # SSS make 1000 a var?
		$sph->SetLimits($qoptions->{offset_num} || 0, $qoptions->{fetch_size}, $qoptions->{maxmatches});
	}



	# SPHINX CALL
	my($sdebug_idset_elapsed, $sdebug_get_elapsed) = (0, 0);
	if (!@$sphinx_ar) {
		$sdebug_idset_elapsed = Time::HiRes::time;
		my(@sphinx_ars, @sphinx_statses);
		# make sure we'll go through loop with dummy data if there's no actual multi data
		@$sphinx_opts_multi = [] unless @$sphinx_opts_multi;
		for my $multi (@$sphinx_opts_multi) {
			if ($constants->{sphinx_se}) {
				my @sphinxse_opts;
				for my $opt (@$sphinx_opts, @$multi) {
					my $neg;
					my $opt_str = "$opt->[0]=$opt->[1],";
					if ($opt->[0] eq 'filter') {
						$opt_str .= join ',', @{$opt->[2]};
						$neg = $opt->[3];
					} elsif ($opt->[0] eq 'range') {
						$opt_str .= "$opt->[2],$opt->[3]";
						$neg = $opt->[4];
					}
					if ($neg) {
						$opt_str = '!' . $opt_str;
					}
					push @sphinxse_opts, $opt_str;
				}

				$qoptions->{orderdir} = $options->{orderdir} eq 'ASC' ? 'attr_asc' : 'attr_desc';
				push @sphinxse_opts, "sort=$qoptions->{orderdir}:$qoptions->{orderby}";
				push @sphinxse_opts, "mode=$sphinx->{mode}" if $sphinx->{mode};

				if (@$sphinx_tables > 1 || @$sphinx_opts_multi) {
					push @sphinxse_opts, "limit=$qoptions->{maxmatches}";
					push @sphinxse_opts, "maxmatches=$qoptions->{maxmatches}";
				} else {
					push @sphinxse_opts, "offset=$qoptions->{offset_num}" if length $qoptions->{offset_num};
					push @sphinxse_opts, "limit=$qoptions->{fetch_size}";
					push @sphinxse_opts, "maxmatches=$qoptions->{maxmatches}" if defined $qoptions->{maxmatches};
				}

				my $query = $self->sqlQuote(join ';', @$sphinx_terms, @sphinxse_opts);
				my $swhere = join ' AND ', @$sphinx_where;
				$swhere = " AND $swhere" if $swhere;
				my $stables = join ',', @$sphinx_tables;

				$sphinx_ar = $sphinxdb->sqlSelectColArrayref(
					'sphinx_search.globjid',
					$stables, "query=$query$swhere", $sphinx_other,
					{ sql_no_cache => 1 });
				$sphinx_stats = $sphinxdb->getSphinxStats;

			} else {
				$sph->ResetFilters; # for multi mode
				for my $opt (@$sphinx_opts, @$multi) {
					my $type = shift @$opt;
					if ($type eq 'filter') {
						$sph->SetFilter(@$opt);
					} elsif ($type eq 'range') {
						$sph->SetFilterRange(@$opt);
					}
				}

				my $sresults = $sph->Query(join(' ', @$sphinx_terms));
				if (!defined $sresults) {
					my $err = $sph->GetLastError() || '';
					print STDERR scalar(gmtime) . " $$ gFHE sph err: '$err'\n";
					# return empty results
					$sresults = {
						matches     => [ ],
						total       => 0,
						total_found => 0,
						'time'      => 0,
						words       => 0,
					};
				}
				$sphinx_ar = [ map { $_->{doc} } @{ $sresults->{matches} } ];
				$sphinx_stats = {
					total         => $sresults->{total},
					total_found   => $sresults->{total_found},
					'time'        => $sresults->{'time'},
					words         => $sresults->{words},
				};

				# If $sph_check_sql was set, it means there are further
				# restrictions that must be checked in MySQL.  What we
				# got back is a potentially quite large list of globjids
				# (up to 10,000) which now need to be filtered in MySQL.
				# For now we do this a not-very-smart way (check the
				# whole list at once instead of repeated splices, and
				# if we end up with not enough, don't repeat the Sphinx
				# query with SetLimits(offset)).

				if ($sphinx->{check_sql} && @$sphinx_ar) {
					my $in = 'IN (' . join(',', @$sphinx_ar) . ')';
					my @sph_tables = grep { $_ ne 'sphinx_search' } @$sphinx_tables;
					my $sphtables = join ',', @sph_tables;
					# note: see above, where this clause is added:
					# 'tags.globjid = sphinx_search.globjid'
					my @sph_where =
						map { s/\s*=\s*sphinx_search\.globjid/ $in/; $_ }
						@$sphinx_where;
					my $sphwhere = join ' AND ', @sph_where;
					$sphinx_ar = $sphinxdb->sqlSelectColArrayref(
						'globjid',
						$sphtables, $sphwhere, $sphinx_other,
						{ sql_no_cache => 1 });
					print STDERR sprintf("%s sphinx:sph_check_sql: %d char where found %d\n",
						scalar(gmtime),
						length($sphwhere),
						scalar(@$sphinx_ar)
					) if $sphinx_debug;
				}
			}
			push @sphinx_ars, $sphinx_ar;
			push @sphinx_statses, $sphinx_stats;
		}

		# merge and re-order; if only one element in array, not multi:
		# use existing $sphinx_ar, $sphinx_stats values
		if (@sphinx_ars > 1) {
			my %uniq;
			my @globjids = grep { !$uniq{$_}++ } map { @$_ } @sphinx_ars;

			# SSS not sure how to merge "words" (we currently
			# do not use "words" at all, so not important) -- pudge

			# total_found is not quite the total number of globjids
			# we have; it could be larger, but if it is, we likely
			# won't ever return them anyway
			my $stats = {
				'time'       => 0,
				total_found  => scalar(@globjids)
			};

			# we don't really care about this, but might as well
			# add it up just in case
			$stats->{'time'} += $_->{'time'} for @sphinx_statses;

			$sphinx_ar = $sphinxdb->sqlSelectColArrayref('globjid', 'firehose',
				sprintf(q{globjid IN (%s)}, join(',', @globjids)),
				"ORDER BY $options->{orderby} $options->{orderdir} $sphinx_other"
			);

			$stats->{total} = scalar @$sphinx_ar;
			$sphinx_stats = $stats;
		}

		$sdebug_idset_elapsed = Time::HiRes::time - $sdebug_idset_elapsed;

		if ($mcdkey_data) {
			# keep this 45 seconds the same as cache
			# in common.js:getFirehoseUpdateInterval
			my $exptime = 45;
			$mcd->set($mcdkey_data, $sphinx_ar, $exptime);
			$mcd->set($mcdkey_stats, $sphinx_stats, $exptime);
		}
	}



	# GET DATA
	$sdebug_get_elapsed = Time::HiRes::time;
	my $hr_hr = $self->getFireHoseByGlobjidMulti($sphinx_ar);
	for my $globjid (@$sphinx_ar) {
		push @$items, $hr_hr->{$globjid};
	}
	$sdebug_get_elapsed = Time::HiRes::time - $sdebug_get_elapsed;



	# GET STATS
# SSS: don't think we need this, but don't remove it yet
# 	if ($fetch_extra && @$items == $qoptions->{fetch_size}) {
# 		$fetch_extra = pop @$items;
# 		($day_num, $day_label, $day_count) = $self->getNextDayAndCount(
# 			$fetch_extra, $options, $tables, \@where, $count_other
# 		);
# 	}

	my $count = $sphinx_stats->{total_found};
	my $sphinx_stats_tf = $sphinx_stats->{total_found};
	$results->{records_pages} ||= ceil($count / $page_size);
	$results->{records_page}  ||= (int(($options->{offset} || 0) / $options->{limit}) + 1) || 1;
	my $future_count = $count - $options->{limit} - ($options->{offset} || 0);

	if ($sphinx_debug) {
		use Data::Dumper; local $Data::Dumper::Indent = 0; local $Data::Dumper::Sortkeys = 1;
		print STDERR sprintf("%s sphinx: idset=%.6f get=%.6f sc=%d c=%d %s\n",
			scalar(gmtime),
			$sdebug_idset_elapsed, $sdebug_get_elapsed,
			$sphinx_stats_tf, $count,
			Dumper([$sphinx_opts, $sphinx_terms, $sphinx_where, $sphinx_tables])
		);
	}

	slashProf("", "fh_GFHE");
	return($items, $results, $count, $future_count, $day_num, $day_label, $day_count);
}}

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

	my $rows = $self->sqlSelectAllHashrefArray("firehose.id", $tables, $where, $other);
	my $row_num = @$rows;
	my $day_count = $row_num;

	if ($row_num == 1 && !$other) {
		$day_count = $rows->[0]->{'count(*)'};
	}

	my $day_labels = getOlderDaysFromDay($item_day, 0, 0, { skip_add_today => 1, show_future_days => 1, force => 1 });

	return($day_labels->[0][0], $day_labels->[0][1], $day_count);
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

	my $metaup =   "metanod";
	my $metadown = "metanix";

	my $tags = getObject("Slash::Tags", { db_type => "reader" });
	my $upid = $tags->getTagnameidCreate($upvote);
	my $dnid = $tags->getTagnameidCreate($downvote);
	my $metaupid = $tags->getTagnameidCreate($metaup);
	my $metadnid = $tags->getTagnameidCreate($metadown);

	my $results = $self->sqlSelectAllKeyValue(
		"globjid,tagnameid",
		"tags",
		"globjid IN ($glob_str) AND inactivated IS NULL
		 AND uid = $uid_q AND tagnameid IN ($upid,$dnid,$metaupid,$metadnid)"
	);

	for my $globjid (keys %$results) {
		my $tnid = $results->{$globjid};
		if ($tnid == $upid || $tnid == $metaupid) {
			$results->{$globjid} = "up";
		} elsif ($tnid == $dnid || $tnid == $metadnid) {
			$results->{$globjid} = "down";
		}
	}
	return $results;
}

sub getFireHoseBySidOrStoid {
	my($self, $id) = @_;
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return $self->getFireHoseByTypeSrcid("story", $stoid);
}

sub getFireHoseByTypeSrcid {
	my($self, $type, $id) = @_;
	my $type_q = $self->sqlQuote($type);
	my $id_q   = $self->sqlQuote($id);
	my $exptime = 86400 * 7;
	my $item = {};

	my $mcd = $self->getMCD();
	my $mcdkey;
	my $fid;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:fhid_type_srcid:$type:$id";
		$fid = $mcd->get($mcdkey);
	}
	if (!$fid) {
		$fid = $self->sqlSelect("id", "firehose", "srcid=$id_q AND type=$type_q");
		if ($mcd && $fid) {
			$mcd->set($mcdkey, $fid, $exptime);
		}
	}
	$item = $self->getFireHose($fid) if $fid;
	return $item;
}

# getFireHose and getFireHoseMulti are the standard ways to retrieve
# a firehose item's data, given its firehose id.  It is recommended
# that all item data retrieval bottleneck through here, to take full
# advantage of caching.

sub getFireHose {
	my($self, $id, $options) = @_;
	slashProf("fh_getFH");
	if ($id !~ /^\d+$/) {
		print STDERR scalar(gmtime) . " getFireHose($id) caller=" . join(':', (caller(0))[1,2]) . "\n";
		return undef;
	}
	my $hr = $self->getFireHoseMulti([$id], $options);
	slashProf("","fh_getFH");
	return $hr->{$id};
}

sub getFireHoseMulti {
	my($self, $id_ar, $options) = @_;
	slashProf("fh_getFHMulti");
	my $constants = getCurrentStatic();
	$id_ar = [ $id_ar ] if !ref $id_ar;
	$id_ar = [( grep { /^\d+$/ } @$id_ar )];

	my $exptime = $constants->{firehose_memcached_exptime} || 600;
	my $ret_hr = { };

	my $mcd_hr = { };
	my $mcd = $self->getMCD();
	my $mcdkey;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:firehose";
		$mcd_hr = $mcd->get_multi(@$id_ar) unless $options->{memcached_no_read};
	}

	my $answer_hr = { };
	my @remaining_ids = ( );
	if (!$options->{memcached_hits_only}) {
		@remaining_ids = ( grep { !defined($mcd_hr->{$_}) } @$id_ar );
	}
	my $splice_count = 2000;
	while (@remaining_ids) {
		my @id_chunk = splice @remaining_ids, 0, $splice_count;
		my $id_str = join(',', @id_chunk);
		my $more_hr = $self->sqlSelectAllHashref('id',
			'*,
				firehose.popularity AS userpop,
				UNIX_TIMESTAMP(firehose.createtime) AS createtime_ut',
			'firehose, firehose_text',
			"firehose.id IN ($id_str) AND firehose.id=firehose_text.id");
		# id's that don't match are ignored from here on out
		@id_chunk = keys %$more_hr;

		# globj adminnotes are never the empty string, they are undef
		# instead.  But firehose notes are (were designed to)
		# never be undef, they are the empty string instead.
		# Add a note field to each hose item hashref.
		my @globjids = ( map { $more_hr->{$_}{globjid} } @id_chunk );
		my $note_hr = $self->getGlobjAdminnotes(\@globjids);
		for my $id (@id_chunk) {
			$more_hr->{$id}{note} = $note_hr->{ $more_hr->{$id}{globjid} } || '';
		}

		# XXX faster, or slower, than iterating over $more_hr?
		$answer_hr = {( %$answer_hr, %$more_hr )};
	}

	if ($mcd && %$answer_hr && !$options->{memcached_no_write}) {
		for my $id (keys %$answer_hr) {
			$mcd->set("$mcdkey:$id", $answer_hr->{$id}, $exptime);
		}
	}

	$ret_hr = {( %$mcd_hr, %$answer_hr )};
	slashProf("", "fh_getFHMulti");
	return $ret_hr;
}

# Like getFireHose, but does the lookup by globjid (which is unique).
#
# One way to implement this would be to store complete hose data with
# each globjid, the advantage being half as many memcached requests
# and thus half the latency.  I wouldn't mind paying most of the price
# for this:  extra memcached RAM, and extra network bandwidth in some
# cases.  But that would also interleave hose item cache expiration
# times, which could lead to confusing bugs.  To avoid that, I'm
# willing to pay the price of extra latency.
#
# So instead this does a lookup from globjid to id (which is cached),
# and wraps that conversion about a getFireHoseMulti call.
#
# The option id_only skips the step of retrieving the actual firehose
# data and returns a hashref (or values of hashrefs) with only the
# id field populated.

sub getFireHoseByGlobjid {
	my($self, $globjid, $options) = @_;
	my $hr = $self->getFireHoseByGlobjidMulti([$globjid], $options);
	return $hr->{$globjid};
}

sub getFireHoseByGlobjidMulti {
	my($self, $globjid_ar, $options) = @_;
	my $ret_hr = { };

	# First, convert the globjids to ids.

	my $exptime = 86400*7; # very long because id<->globjid never changes
	my $globjid_to_id_hr = { };

	my $mcd_hr = { };
	my $mcd = $self->getMCD();
	my $mcdkey;
	$mcdkey = "$self->{_mcd_keyprefix}:gl2id" if $mcd;
	if ($mcd && !$options->{memcached_no_read}) {
		my @keylist = ( map { "$mcdkey:$_" } @$globjid_ar );
		my $mcdkey_hr = $mcd->get_multi(@keylist);
		for my $k (keys %$mcdkey_hr) {
			my($id) = $k =~ /^\Q$mcdkey:\E(\d+)$/;
			next unless $id;
			$mcd_hr->{$id} = $mcdkey_hr->{$k};
		}
	}

	my $answer_hr = { };
	my @remaining_ids = ( grep { !defined($mcd_hr->{$_}) } @$globjid_ar );
	my $splice_count = 2000;
	while (@remaining_ids) {
		my @globjid_chunk = splice @remaining_ids, 0, $splice_count;
		my $globjid_str = join(',', @globjid_chunk);
		my $more_hr = $self->sqlSelectAllKeyValue(
			'globjid, id',
			'firehose',
			"globjid IN ($globjid_str)");
		# XXX faster, or slower, than iterating over $more_hr?
		$answer_hr = {( %$answer_hr, %$more_hr )};
	}

	if ($mcd && %$answer_hr && !$options->{memcached_no_write}) {
		for my $globjid (keys %$answer_hr) {
			$mcd->set("$mcdkey:$globjid", $answer_hr->{$globjid}, $exptime);
		}
	}

	$globjid_to_id_hr = {( %$mcd_hr, %$answer_hr )};

	# If only the ids are desired, we can return those now.
	if ($options->{id_only}) {
		return $globjid_to_id_hr;
	}

	# Now that the globjids have been converted to ids, call
	# getFireHoseMulti.

	my @ids = grep { $_ } map { $globjid_to_id_hr->{$_} } @$globjid_ar;
	my $firehose_hr = $self->getFireHoseMulti(\@ids, $options);
use Data::Dumper; print STDERR scalar(gmtime) . " $$ gFHM returned non-hashref from '@ids' options: " . Dumper($options) if ref($firehose_hr) ne 'HASH';

	# Then convert the keys in the answer back to globjids.
	for my $id (keys %$firehose_hr) {
if (ref($firehose_hr->{$id}) ne 'HASH') {
my $opt_str = Dumper($options); $opt_str =~ s/\s+/ /g;
my $fh_str = Dumper($firehose_hr); $fh_str =~ s/\s+/ /g;
print STDERR scalar(gmtime) . " $$ gFHM returned non-hashref-hashref for '$id' from '@ids' options '$opt_str' fh '$fh_str'\n";
next;
}
		$ret_hr->{ $firehose_hr->{$id}{globjid} } = $firehose_hr->{$id};
	}
	return $ret_hr;
}

sub getFireHoseIdFromGlobjid {
	my($self, $globjid) = @_;
	return $self->getFireHoseByGlobjid($globjid, { id_only => 1 });
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
	# The URL is made into an <a href> so, on being parsed, it will
	# also be canonicalized.
	my $url_prepend = $url ? qq{<a href="$url">$url</a>} : '';
	my $urls_ar = getUrlsFromText($url_prepend, $item->{introtext}, $item->{bodytext});
	return sort @$urls_ar;
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

	my $tags = getObject("Slash::Tags", { db_type => 'reader' })->setGetCombinedTags($id, 'firehose-id');
	my $data = {
		item		=> $item,
		mode		=> "bodycontent",
		tags_top	=> $tags_top,		# old-style
		top_tags	=> $tags->{top},	# new-style
		system_tags	=> $tags->{'system'},	# new-style
		datatype_tags	=> $tags->{'datatype'},	# new-style
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
	my($self, $id) = @_;
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
	my $views = $firehose->getUserViews({ tab_display => "yes"});
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs}, options => $opts, section => $form->{section}, views => $views }, { Return => 1});

	return Data::JavaScript::Anon->anon_dump({
		html	=> $html
	});
}


sub genSetOptionsReturn {
	my($slashdb, $constants, $user, $form, $options, $opts) = @_;
	my $data = {};

	my $firehose = getObject("Slash::FireHose");
	my $views = $firehose->getUserViews({ tab_display => "yes"});
	$data->{html}->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs}, options => $opts, section => $form->{section}, views => $views  }, { Return => 1});
	$data->{html}->{fhoptions} = slashDisplay("firehose_options", { nowrapper => 1, options => $opts }, { Return => 1});
	$data->{html}->{fhadvprefpane} = slashDisplay("fhadvprefpane", { options => $opts }, { Return => 1});

	my $event_data = {
		id		=> $form->{section},
		filter		=> strip_literal($opts->{fhfilter}),
		viewname	=> $form->{view},
		color		=> strip_literal($opts->{color}),
	};

	$data->{value}->{'firehose-filter'} = $opts->{fhfilter};
	my $section_changed = $form->{section} && $form->{sectionchanged};
	if (($form->{view} && $form->{viewchanged}) || $section_changed) {
		$data->{eval_last} = "firehose_swatch_color('$opts->{color}');";
		$event_data->{'select_section'} = $section_changed;
	}
	$data->{events} = [{
		event	=> 'set-options.firehose',
		data	=> $event_data,
	}];

	my $eval_first = "";
	for my $o (qw(startdate mode fhfilter orderdir orderby startdate duration color more_num tab view viewtitle fhfilter base_filter sectionname)) {
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
		$data->{eval_first} .= "view_change_hide_show(firehose_settings.view);";
	}
	if ($options->{resetfilter}) {
		$data->{eval_first} .= "set_filter_inputs(firehose_settings.fhfilter);";
	}
	my $fh_is_admin =  $user->{is_admin} && !$opts->{usermode} ? 1 : 0;

	$data->{eval_first} .= "fh_is_admin = $fh_is_admin;";;
	if ($opts->{viewref}) {
		$data->{eval_first} .= "\$('#viewsearch').val(" . Data::JavaScript::Anon->anon_dump($opts->{viewref}{viewtitle}) . ");";
		if ($opts->{viewref}{searchbutton} eq 'no') {
			$data->{eval_first} .= "\$('#viewsearch').hide();";
		} else {
			$data->{eval_first} .= "\$('#viewsearch').show();";
		}
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
	return $note || "<img src='$constants->{imagedir}/sic_notes.png' alt='Note'>";
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
	my $views = $firehose->getUserViews({ tab_display => "yes"});
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs}, options => $opts, section => $form->{section}, views => $views }, { Return => 1});
	$html->{message_area} = $message;
	return Data::JavaScript::Anon->anon_dump({
		html	=> $html
	});
}


sub ajaxFireHoseGetUpdates {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $gSkin = getCurrentSkin();
	my $start = Time::HiRes::time();

	slashProfInit();
	slashProf("fh_ajax_gup");

	my $update_data = { removals => 0, items => 0, updates => 0, new => 0, updated_tags => {} };

	$options->{content_type} = 'application/json';
	my $title_js = '';
	my $firehose = getObject("Slash::FireHose");
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $id_str = $form->{ids};
	my $update_time = $form->{updatetime};
	my @ids = grep {/^(\d+|day-\d+\w?)$/} split (/,/, $id_str);
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
	$adminmode = 0 if $user->{is_admin} && $opts->{usermode};
	my $ordered = [];
	my $now = $slashdb->getTime();
	my $added = {};

	my $last_day;
	my $mode = $opts->{mode};
	my $curmode = $opts->{mode};
	my $mixed_abbrev_pop = $firehose->getMinPopularityForColorLevel(1);
	my $vol = $firehose->getSkinVolume($gSkin->{skid});
	$vol->{story_vol} ||= 0;
	if ($vol->{story_vol} < 25) {
		$mixed_abbrev_pop = $firehose->getMinPopularityForColorLevel(3);
	}
	if ($opts->{view} eq "popular") {
		$mixed_abbrev_pop = $firehose->getMinPopularityForColorLevel(4);
	}

	my $item_number = 0;
	foreach (@$items) {
		$item_number++;
		if ($opts->{mode} eq "mixed") {
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
					$item->{atstorytime} = '__TIME_TAG__';
					my $title = slashDisplay("formatHoseTitle", { adminmode => $adminmode, item => $item, showtitle => 1, url => $url, the_user => $the_user, options => $opts }, { Return => 1 });

					my $atstorytime;
					$atstorytime = $user->{aton} . ' ' . timeCalc($item->{'createtime'});
					$title =~ s/\Q__TIME_TAG__\E/$atstorytime/g;

					$title_js .= "\$('\#title-" . $_->{id} . "').html(" . Data::JavaScript::Anon->anon_dump($title) . ");\n";
					$title_js .= "inject_reasons('#firehose-" . $_->{id} . "')";

					my $introtext = $item->{introtext};
					slashDisplay("formatHoseIntro", { introtext => $introtext, url => $url, $item => $item }, { Return => 1 });
					$html->{"text-$_->{id}"} = $introtext;
					$html->{"fhtime-$_->{id}"} = timeCalc($item->{createtime});
					$html->{"topic-$_->{id}"} = slashDisplay("dispTopicFireHose", { item => $item, adminmode => $adminmode }, { Return => 1});

					$update_data->{updated_tags}{$_->{id}}{top_tags} = $item->{toptags};
					$update_data->{updated_tags}{$_->{id}}{system_tags} = $firehose->getFireHoseSystemTags($item);
					$update_data->{updates}++;
					# updated
				}
			}
		} else {
			# new

			my $insert_loc = $item_number > (scalar @$items / 2) ? "bottom" : "top";
			$update_time = $_->{last_update} if $_->{last_update} gt $update_time && $_->{last_update} lt $now;
			if ($_->{day}) {
				push @$updates, ["add", $_->{id}, slashDisplay("daybreak", { options => $opts, cur_day => $_->{day}, last_day => $_->{last_day}, id => "firehose-day-$_->{day}", fh_page => $base_page }, { Return => 1, Page => "firehose" }), $insert_loc ];
			} else {
				$update_data->{new}++;
				my $tags = getObject("Slash::Tags", { db_type => 'reader' })->setGetCombinedTags($_->{id}, 'firehose-id');
				my $data = {
					mode => $curmode,
					item => $item,
					tags_top => $tags_top,			# old-style
					top_tags => $tags->{top},		# new-style
					system_tags => $tags->{'system'},	# new-style
					datatype_tags => $tags->{'datatype'},	# new-style
					vote => $votes->{$item->{globjid}},
					options => $opts
				};
				slashProf("firehosedisp");
				push @$updates, ["add", $_->{id}, $firehose->dispFireHose($item, $data), $insert_loc ];
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
		my($key) = keys %$next_to_old;
		$target_pos = $pos->{$key};

	}

	@$updates  = sort {
		$next_to_old->{$a->[1]} <=> $next_to_old->{$b->[1]} ||
		abs($pos->{$b->[1]} - $target_pos) <=> abs($pos->{$a->[1]} - $target_pos);
	} @$updates;

	foreach (keys %ids) {
		push @$updates, ["remove", $_, "",""];
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
		items              => $items,
		contentsonly       => 1,
		day                => $last_day,
		last_day           => $last_day,
		page               => $form->{page},
		options            => $opts,
		ulid               => "fh-paginate",
		divid              => "fh-pag-div",
		num_items          => $num_items,
		fh_page            => $base_page,
		firehose_more_data => $firehose_more_data,
		split_refresh	   => 1
	}, { Return => 1, Page => "firehose" });

	$html->{firehose_pages} = slashDisplay("firehose_pages", {
		page            => $form->{page},
		num_items       => $num_items,
		fh_page         => $base_page,
		options         => $opts,
		contentsonly    => 1,
		search_results  => $results
	}, { Return => 1 });

	my $recent = $slashdb->getTime({ add_secs => "-300"});
	$update_time = $recent if $recent gt $update_time;
	my $values = {};

	my $skid = $firehose->getSectionSkidFromFilter("$opts->{base_filter}");
	my $skin = $firehose->getCSSForSkid($skid, $form->{layout});

	my $update_event = {
		event		=> 'update.firehose',
		data		=> {
			color		=> strip_literal($opts->{color}),
			filter		=> strip_literal($opts->{fhfilter}),
			view		=> strip_literal($opts->{view}),
			local_time	=> timeCalc($slashdb->getTime(), "%H:%M"),
			gmt_time	=> timeCalc($slashdb->getTime(), "%H:%M", 0),
			skin		=> $skin
		},
	};
	my $events = [ $update_event ];

	$html->{local_last_update_time} = timeCalc($slashdb->getTime(), "%H:%M");
	$html->{filter_text} = "Filtered to ".strip_literal($opts->{color})." '".strip_literal($opts->{fhfilter})."'";
	$html->{gmt_update_time} = " (".timeCalc($slashdb->getTime(), "%H:%M", 0)." GMT) " if $user->{is_admin};
	$html->{itemsreturned} = getData("noitems", { options => $opts }, 'firehose') if $num_items == 0;
#	$html->{firehose_more} = getData("firehose_more_link", { options => $opts, future_count => $future_count, contentsonly => 1, day_label => $day_label, day_count => $day_count }, 'firehose');

	my $dynamic_blocks_reader = getObject("Slash::DynamicBlocks");
	my $dynamic_blocks;
	if ($dynamic_blocks_reader) {
		$dynamic_blocks = $dynamic_blocks_reader->getBlocksEligibleForUpdate($form->{dynamic_blocks}, { min_time => $update_time });
	}

	my $sprite_info = $firehose->getSpriteInfoByFHID($ordered->[0]);

	my $color_js = "\$('.currcolor').removeClass('red orange yellow green blue violet indigo black').addClass('$opts->{color}');";
	my $eval_last = "$color_js $title_js";

	my $data_dump =  Data::JavaScript::Anon->anon_dump({
		html		=> $html,
		eval_last	=> $eval_last,
		updates		=> $updates,
		update_time	=> $update_time,
		update_data	=> $update_data,
		ordered		=> $ordered,
		future		=> $future,
		value 		=> $values,
		events		=> $events,
		dynamic_blocks  => $dynamic_blocks,
		sprite_info     => $sprite_info,
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
	slashProf("","fh_ajax_gup");
	slashProfEnd("FHPROF_AJAXUP");

	return $retval;

}

sub firehose_vote {
	my($self, $id, $uid, $dir, $meta) = @_;
	my $tag;
	my $constants = getCurrentStatic();
	my $tags = getObject('Slash::Tags');
	my $item = $self->getFireHose($id);
	return if !$item;

	my $upvote   = $constants->{tags_upvote_tagname}   || 'nod';
	my $downvote = $constants->{tags_downvote_tagname} || 'nix';

	if ($meta) {
		$upvote = "metanod";
		$downvote = "metanix";
	}

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
	my $meta = $form->{meta};

	my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});

	$firehose->firehose_vote($id, $user->{uid}, $form->{dir}, $meta);

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

	if ($user->{is_admin}) {
		$firehose->setFireHoseSession($item->{id});
	}

	my $the_user = $slashdb->getUser($item->{uid});

	$item->{atstorytime} = '__TIME_TAG__';
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

	my $atstorytime;
	$atstorytime = $user->{aton} . ' ' . timeCalc($item->{'createtime'});
	$byline =~ s/\Q__TIME_TAG__\E/$atstorytime/g;

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
		my @non_trivial = grep {!/^activity$/} keys %$data;
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

	if (defined $data->{primaryskid}) {
		my $type = $data->{type};
		if (!$type) {
			my $item = $self->getFireHose($id);
			$type = $item->{type};
		}
		if ($type ne "story") {
			$self->setTopicsRenderedBySkidForItem($id, $data->{primaryskid});
		}
	}

	$self->deleteFireHoseCaches([ $id ], 1);

	return $rows;
}

sub deleteFireHoseCaches {
	my($self, $id_ar, $all) = @_;
	my $mcd = $self->getMCD();
	return if !$mcd;

	my $mcdkey = "$self->{_mcd_keyprefix}:firehose";
	my %cache_key = ( );
	for my $id (@$id_ar) {
		$cache_key{"$mcdkey:$id"} = 1;
		next if !$all;
		my $keys = $self->genFireHoseMCDAllKeys($id);
		for my $k (@$keys) { $cache_key{$k} = 1 }
	}

	for my $k (keys %cache_key) {
		$mcd->delete($k, 3);
	}
}


# This generates the key for memcaching dispFireHose results
# if no key is returned no caching or fetching from cache will
# take place in dispFireHose.

sub genFireHoseMCDKey {
	my($self, $id, $options) = @_;
	my $gSkin = getCurrentSkin();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my $opts = $options->{options} || {};

	my $mcd = $self->getMCD();
	my $mcdkey;

	return '' if $gSkin->{skid} != $constants->{mainpage_skid};
	return '' if !$constants->{firehose_mcd_disp};

	my $index = $form->{index} ? 1 : 0;

	if ($mcd
		&& !$opts->{nocolors}
		&& !$opts->{nothumbs} && !$options->{vote}
		&& !$form->{skippop}
		&& !$user->{is_admin}
		&& !$opts->{view_mode}
		&& !$opts->{featured}) {
		$mcdkey = "$self->{_mcd_keyprefix}:dispfirehose-$options->{mode}:$id:$index";
	}
	return $mcdkey;
}

sub genFireHoseMCDAllKeys {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	return [ ] if !$constants->{firehose_mcd_disp};
	my $keys = [ ];
	my $mcd = $self->getMCD();

	if ($mcd) {
		foreach my $mode (qw(full fulltitle)) {
			foreach my $index (qw(0 1)) {
				push @$keys, "$self->{_mcd_keyprefix}:dispfirehose-$mode:$id:$index";
			}
		}
	}
	return $keys;
}

sub dispFireHose {
	my($self, $item, $options) = @_;
	slashProf("fh_dispFireHose");
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$options ||= {};
	my $mcd = $self->getMCD();
	my $mcdkey;
	my $retval;

	if ($mcd) {
		$mcdkey = $self->genFireHoseMCDKey($item->{id}, $options);
		if ($mcdkey) {
			$retval = $mcd->get("$mcdkey");
		}
	}

	$item->{atstorytime} = "__TIME_TAG__";

	if (!$retval) {  # No cache hit
		$retval = slashDisplay('dispFireHose', {
			item			=> $item,
			mode			=> $options->{mode},
			tags_top		=> $options->{tags_top},	# old-style
			top_tags		=> $options->{top_tags},	# new-style
			system_tags		=> $options->{system_tags},	# new-style
			options			=> $options->{options},
			vote			=> $options->{vote},
			bodycontent_include	=> $options->{bodycontent_include},
			nostorylinkwrapper	=> $options->{nostorylinkwrapper},
			view_mode		=> $options->{view_mode},
			featured		=> $options->{featured},
			related_stories		=> $options->{related_stories},
			book_info               => $options->{book_info},
		}, { Page => "firehose",  Return => 1 });

		if ($mcd) {
			$mcdkey = $self->genFireHoseMCDKey($item->{id}, $options);
			if ($mcdkey) {
				my $exptime = $constants->{firehose_memcached_disp_exptime} || 180;
				$mcd->set($mcdkey, $retval, $exptime);
			}
		}
	}

	my $tag_widget = slashDisplay('tag_widget', {
		id 		=> $item->{id},
		top_tags 	=> $options->{top_tags},
		system_tags 	=> $options->{system_tags},
		vote 		=> $options->{vote},
		options 	=> $options->{options},
		item 		=> $item,
		skipvote 	=> 1
	}, { Return => 1, Page => 'firehose'});

	my $atstorytime;
	$atstorytime = $user->{aton} . ' ' . timeCalc($item->{'createtime'});
	$retval =~ s/\Q__TIME_TAG__\E/$atstorytime/g;

	$retval =~ s/\Q__TAG_WIDGET__/$tag_widget/g;
	slashProf("","fh_dispFireHose");

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
			$url =~ m/$match/i
		) {
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

sub getOptionsValidator {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $colors = $self->getFireHoseColors();
	my %categories = map { ($_, $_) } (qw(hold quik),
		(ref $constants->{submit_categories}
			? map {lc($_)} @{$constants->{submit_categories}}
			: ()
		)
	);

	my $valid = {
		mode 		=> { full => 1, fulltitle => 1, mixed => 1 },
		type 		=> { feed => 1, bookmark => 1, submission => 1, journal => 1, story => 1, vendor => 1, misc => 1, comment => 1, project => 1 },
		orderdir 	=> { ASC => 1, DESC => 1},
		orderby 	=> { createtime => 1, popularity => 1, editorpop => 1, neediness => 1 },
		pagesizes 	=> { "tiny" => 1, "small" => 1, "large" => 1 },
		colors		=> $colors,
		categories 	=> \%categories
	};

	if ($user->{is_admin} || $user->{is_subscriber}) {
		$valid->{pagesizes}->{huge} = 1;
	}
	if ($user->{is_admin}) {
		$valid->{pagesizes}->{single} = 1;
	}
	return $valid;
}

sub getGlobalOptionDefaults {
	my($self) = @_;

	my $defaults = {
		pause		=> 1,
		mode 		=> 'full',
		orderdir	=> 'DESC',
		orderby		=> 'createtime',
		mixedmode 	=> 0,
		nodates		=> 0,
		nobylines	=> 0,
		nothumbs	=> 0,
		nocolors	=> 0,
		nocommentcnt	=> 0,
		noslashboxes 	=> 0,
		nomarquee	=> 0,
		pagesize	=> "small",
		usermode	=> 0,
	};

	return $defaults;
}

sub getAndSetGlobalOptions {
	my($self) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $options = $self->getGlobalOptionDefaults();
	my $validator = $self->getOptionsValidator();
	my $set_options = {};

	if (!$user->{is_anon}) {
		foreach (keys %$options) {
			my $set_opt = 0;
			if (defined $form->{$_} && $form->{setting_name} eq $_ && $form->{context} eq "global") {
				if (defined $validator->{$_}) {
					if ($validator->{$_}{$form->{$_}}) {
						$set_options->{"firehose_$_"} = $form->{$_};
						$options->{$_} = $set_options->{"firehose_$_"};
						$set_opt = 1;
					}
				} else {
					$set_opt = 1;
					$set_options->{"firehose_$_"} = $form->{$_} ? 1 : 0;
					$options->{$_} = $set_options->{"firehose_$_"};
				}
			}

			# if we haven't set the option, pull from saved user options
			if (!$set_opt) {
				$options->{$_} = $user->{"firehose_$_"} if defined $user->{"firehose_$_"};
			}
		}
		if (keys %$set_options > 0) {
			$self->setUser($user->{uid}, $set_options);
		}
	}
	return $options;
}

sub getShortcutUserViews {
	my($self) = @_;
	return $self->sqlSelectAllHashref("viewname","viewname","firehose_view", "uid=0");
}

sub getUserViews {
	my($self, $options) = @_;
	my $user = getCurrentUser();

	my($where, @where);

	my @uids = (0);

	if ($options->{tab_display}) {
		push @where, "tab_display=" . $self->sqlQuote($options->{tab_display});
		if ($user->{is_anon}) {
			push @where, "viewname not like 'user%'";
		}
	}

	if ($options->{editable}) {
		push @where, "editable=" . $self->sqlQuote($options->{editable});
	}

	if (!$user->{is_anon}) {
		push @uids, $user->{uid};
		push @where, "uid in (" . (join ',', @uids) . ")";
	}
	push @where, "seclev <= $user->{seclev}";

	$where = join ' AND ', @where;
	my $items = $self->sqlSelectAllHashrefArray("*","firehose_view", $where, "ORDER BY uid, id");
	foreach (@$items) {
		my $strip_nick = strip_paramattr($user->{nickname});
		$_->{viewtitle} =~ s/{nickname}/$user->{nickname}/g;
		$_->{short_url} =~ s/{nickname}/$strip_nick/g;
	}
	return $items;
}

sub getUserViewById {
	my($self, $id, $options) = @_;
	my $user = getCurrentUser();

	my $uid_q = $self->sqlQuote($user->{uid});
	my $id_q = $self->sqlQuote($id);

	return $self->sqlSelectHashref("*", "firehose_view", "uid in (0,$uid_q) && id = $id_q and seclev<=$user->{seclev}");
}

sub getUserViewByName {
	my($self, $name, $options) = @_;
	my $user = getCurrentUser();
	my $uid_q = $self->sqlQuote($user->{uid});
	my $name_q = $self->sqlQuote($name);
	my $uview = $self->sqlSelectHashref("*", "firehose_view", "uid=$uid_q && viewname = $name_q");

	return $uview if $uview;

	my $sview =  $self->getSystemViewByName($name);

	return $sview;
}

sub getSystemViewByName {
	my($self, $name, $options) = @_;
	my $user = getCurrentUser();
	my $name_q = $self->sqlQuote($name);
	return $self->sqlSelectHashref("*", "firehose_view", "uid=0 && viewname = $name_q and seclev <= $user->{seclev}");
}

sub determineCurrentSection {
	my($self) = @_;
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $section;

	# XXX what to do if fhfilter is specified?

	if ($form->{section}) {
		$section = $self->getFireHoseSection($form->{section});
	}

	if (!$section && !$section->{fsid}) {
		if ($user->{firehose_default_section} && $gSkin->{skid}== $constants->{mainpage_skid}) {
			$section = $self->getFireHoseSection($user->{firehose_default_section});
		} else {
			$section = $self->getFireHoseSectionBySkid($gSkin->{skid});
		}
	}

	$section = $self->applyUserSectionPrefs($section);
	return $section;
}

sub applyUserViewPrefs {
	my($self, $view) = @_;
	my $constants = getCurrentStatic();
	my $user_prefs = $self->getViewUserPrefs($view->{id});
	if ($user_prefs) {
		foreach (qw(color mode datafilter usermode admin_unsigned orderby orderdir)) {
			$view->{$_} = $user_prefs->{$_}
		}
	}
	return $view;
}

sub applyUserSectionPrefs {
	my($self, $section) = @_;
	my $constants = getCurrentStatic();
	if ($section->{uid} == 0) {
		my $user_prefs = $self->getSectionUserPrefs($section->{fsid});
		if ($user_prefs) {
			foreach (qw(section_name section_filter view_id section_color display)) {
				next if $_ eq "section_name" && $section->{skid} == $constants->{mainpage_skid};
				$section->{$_} = $user_prefs->{$_};
			}
		}
	}
	return $section;
}

sub applyViewOptions {
	my($self, $view, $options, $second) = @_;
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	$view = $self->applyUserViewPrefs($view);
	$options->{view} = $view->{viewname};
	$options->{viewref} = $view;

	my $viewfilter = "$view->{filter}";
	$viewfilter .= " $view->{datafilter}" if $view->{datafilter};
	$viewfilter .= " unsigned" if $user->{is_admin} && $view->{admin_unsigned} eq "yes";

	if ($viewfilter =~ /{nickname}/) {
		my $the_user = $self->getUser($form->{user_view_uid}) || $user;
		$viewfilter =~ s/{nickname}/$the_user->{nickname}/;
	}

	my $validator = $self->getOptionsValidator();

	if ($view->{useparentfilter} eq "no") {
		if (!$second || ($form->{viewchanged} || $form->{sectionchanged})) {
			$options->{fhfilter} = $viewfilter;
			$options->{view_filter} = $viewfilter;
			$options->{base_filter} = $viewfilter;
		}
		if ($form->{viewchanged} || $form->{sectionchanged}) {
			$options->{resetfilter} = 1;
		}
		$options->{tab} = "";
		$options->{tab_ref} = "";
	} else {
		$options->{fhfilter} = "$options->{base_filter}";
		$options->{view_filter} = $viewfilter;
	}

	if ($view->{use_exclusions} eq "yes") {
		if ($user->{story_never_author}) {
			my $author_exclusions;
			foreach (split /,/, $user->{story_never_author}) {
				my $nick = $self->getUser($_, 'nickname');
				$author_exclusions .= " \"-author:$nick\" " if $nick;
			}
			$viewfilter .= $author_exclusions if $author_exclusions;
		}
		if ($user->{firehose_exclusions}) {
			my $base_ops = $self->splitOpsFromString($options->{base_filter});
			my %base_ops = map { $_ => 1 } @$base_ops;
			my $ops = $self->splitOpsFromString($user->{firehose_exclusions});
			my @fh_exclusions;

			my $skins = $self->getSkins();
			my %skin_nexus = map { $skins->{$_}{name} => $skins->{$_}{nexus} } keys %$skins;

			foreach (@$ops) {
				my($not, $op) = $_ =~/^(-?)(.*)$/;
				next if $base_ops{$op};

				if ($validator->{type}{$_}) {
					push @fh_exclusions, "-$op";
				} elsif ($skin_nexus{$_}) {
					push @fh_exclusions, "-$op";
				} else {
					push @fh_exclusions, "-$op";
				}
			}
			if (@fh_exclusions) {
				$viewfilter .= " ". (join ' ', @fh_exclusions)
			}
		}
		$options->{view_filter} = $viewfilter;
	}

	foreach (qw(mode color duration orderby orderdir datafilter)) {
		next if $_ eq "color" && $options->{color} && $view->{useparentfilter} eq "yes";
		$options->{$_} = $view->{$_} if $view->{$_} ne "";
	}

	if (!$second) {
		foreach (qw(pause)) {
			$options->{$_} = $view->{$_} if $view->{$_} ne "";
		}
	}

	$options->{usermode} = 1;

	if ($user->{is_admin}) {
		foreach (qw(usermode admin_unsigned)) {
			$options->{$_} = $view->{$_} eq "yes" ? 1 : 0;
		}
	}
	return $options;
}

sub genUntitledTab {
	my($self, $user_tabs, $options) = @_;
	my $user = getCurrentUser();

	my $tab_compare = {
		filter 		=> "fhfilter"
	};

	my $tab_match = 0;
	foreach my $tab (@$user_tabs) {

		my $this_tab_compare;
		%$this_tab_compare = %$tab_compare;

		my $equal = 1;

		foreach (keys %$this_tab_compare) {
			$options->{$this_tab_compare->{$_}} ||= "";
			if ($tab->{$_} ne $options->{$this_tab_compare->{$_}}) {
				$equal = 0;
			}
		}

		if ($options->{tab} eq $tab->{tabname}) {
			$tab->{active} = 1;
		}

		if ($equal) {
			$tab_match = 1;
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
			$_->{active} = 1 if $_->{tabname} eq "untitled";
		}
	}
	return $user_tabs;
}


{
my $stopwords;
sub sphinxFilterQuery {
	my($query, $mode) = @_;
	# query size is limited, so strip out stopwords
	unless (defined $stopwords) {
		my $sphinxdb = getObject('Slash::Sphinx', { db_type => 'sphinx' });
		my @stopwords = $sphinxdb->getSphinxStopwords;
		if (@stopwords) {
			$stopwords = join '|', @stopwords;
			$stopwords = qr{\b(?:$stopwords)\b};
		} else {
			$stopwords = 0;
		}
	}

	$mode ||= 'all';
	$mode = 'extended2' if $mode eq 'extended';

	my $basic = 'a-zA-Z0-9_ ';

	# SSS what about hyphenated words?
	my $extra = ':\'';  # : and ' are sometimes useful in plain text, like for Perl modules and contractions

	my $boolb = '()&|'; # base boolean syntax
	my $booln = '!\-';  # boolean negation
	my $bool  = $boolb . $booln; # full boolean syntax

	my $extb  = '@\[\],*"~/=';   # base extended syntax
	my $ext   = $bool . $extb;   # full extended syntax

	my $chars = $basic;  # . $extra;  # not until we figure out indexer behavior -- pudge
# SSS: when we do syntax checking later, we may allow those characters
# to pass through -- pudge
#	$chars .= $boolb if $mode eq 'boolean';
	$chars .= $booln if $mode eq 'boolean';
#	$chars .= $ext   if $mode eq 'extended2';

	# keep only these characters
	$query =~ s/[^$chars]+/ /g;

	# clean up spaces
	$query =~ s/ +/ /g; $query =~ s/^ //g; $query =~ s/ $//g;

	$query =~ s/$stopwords//gio if $stopwords;

	# we may want to adjust the mode before returning it
	return($query, $mode);
}
}

# this serialization code can be heavily modified to taste ... it doesn't
# really matter what it spits out, as long as we can rely on it being
# consistent and unique for a given query
{
my @options = (
	# meta search parameters
	qw(
		limit more_num orderby orderdir offset
		startdate startdateraw duration admin_filters
	),
	# other search parameters
	# don't need usermode, since !usermode == no cache
	qw(
		filter color category not_id not_uid public not_public
		accepted not_accepted rejected not_rejected type not_type
		primaryskid not_primaryskid signed unsigned nexus not_nexus
		spritegen tagged_by_uid tagged_as offmainpage smalldevices
		createtime_no_future createtime_subscriber_future
		tagged_non_negative tagged_for_homepage uid
	)
);

# from the user; ideally, we would calculate startdate etc.
# and not use off_set, but in practice not much difference
my @prefs = qw(
	off_set
);

# some things can be arrays; sort numerically unless listed here
my %stringsort = (map { $_ => 1 } qw(
	type not_type
));

sub serializeOptions {
	my($self, $options, $prefs) = @_;

	# copy the data so we can massage it into place
	my $data = {};
	for my $opt (@options) {
		next unless defined $options->{$opt};
		my $ref = ref $options->{$opt};

		if ($ref eq 'ARRAY') {
			# normalize sort
			if ($stringsort{$opt}) {
				$data->{$opt} = [ sort @{ $options->{$opt} } ];
			} else {
				$data->{$opt} = [ sort { $a <=> $b } @{ $options->{$opt} } ];
			}
		} elsif ($ref) {
			errorLog("$opt is a $ref, don't know what to do!");
		} else {
			$data->{$opt} = $options->{$opt};
		}
	}

	# do prefs come before or after options?
	for my $pref (@prefs) {
		$data->{$pref} = $prefs->{$pref} if $prefs && defined $prefs->{$pref};
	}

	local $Data::Dumper::Sortkeys = 1;
	local $Data::Dumper::Indent   = 0;
	local $Data::Dumper::Terse    = 1;
	return Dumper($data);
} }

sub getAndSetOptions {
	my($self, $opts) = @_;
	slashProf("fh_gASO");

	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $form 	= getCurrentForm();
	my $gSkin	= getCurrentSkin();

	my $nick_user = $user;
	if ($opts->{user_view} && $opts->{user_view}{uid}) {
		$form->{user_view_uid} = $opts->{user_view}{uid};
		$nick_user = $self->getUser($form->{user_view_uid}) || $user;
	}

	my $mainpage = 0;

	my($f_change, $v_change, $t_change, $s_change, $search_trigger);

	if (!$opts->{initial}) {
		($f_change, $v_change, $t_change, $s_change, $search_trigger) = ($form->{filterchanged}, $form->{viewchanged}, $form->{tabchanged}, $form->{sectionchanged}, $form->{searchtriggered});
	}

	my $validator = $self->getOptionsValidator();

	$opts 	        ||= {};

	my $global_opts = $self->getAndSetGlobalOptions();
	my $options = {};

	# Beginning of initial pageload handling
	if ($opts->{initial}) {
		# Start off with global options if initial load
		%$options = %$global_opts;

		if (defined $opts->{fhfilter} || defined $form->{fhfilter}) {
			my $fhfilter = defined $opts->{fhfilter} ? $opts->{fhfilter} : $form->{fhfilter};

			$options->{fhfilter} = $fhfilter;
			$options->{base_filter} = $fhfilter;

			$form->{tab} = '';
			$opts->{view} = '';
			$form->{view} ||= 'search';

		} else {

			my $section = $self->determineCurrentSection();

			if ($section && $section->{fsid}) {
				$options->{sectionref} = $section;
				$options->{section} = $section->{fsid};
				$options->{base_filter} = $section->{section_filter};
			}

			if (!$form->{view} && !$opts->{view}) {
				$options->{color} = $section->{section_color};
			}


			# Jump to default view as necessary

			if (!$opts->{view} && !$form->{view}) {
				my $view;
				if ($section) {
					$view = $self->getUserViewById($section->{view_id});
				}

				if ($view && $view->{id}) {
					$opts->{view} = $view->{viewname};
				} else {
					$opts->{view} = "stories";
				}
			}
		}

		my $view;

		if ($opts->{view} || $form->{view}) {
			my $viewname = $opts->{view} || $form->{view};
			$view = $self->getUserViewByName($viewname);
		}
		if ($view) {
			$options = $self->applyViewOptions($view, $options);
		}





	} else {
		my $view_applied = 0;
		# set only global options
		$options->{$_} = $global_opts->{$_} foreach qw(nocommentcnt nobylines nodates nothumbs nomarquee nocolors noslashboxes mixedmode pagesize);

		# handle non-initial pageload
		$options->{fhfilter} = $form->{fhfilter} if defined $form->{fhfilter};
		$options->{base_filter} = $form->{fhfilter} if defined $form->{fhfilter};

		if (($f_change || $search_trigger) && defined $form->{fhfilter}) {
			my $fhfilter = $form->{fhfilter};

			$options->{fhfilter} = $fhfilter;
			$options->{base_filter} = $fhfilter;

			if ($search_trigger) {
				$form->{view} = 'search';
			}

		}

		if ($s_change && defined $form->{section}) {
			my $section = $self->determineCurrentSection();
			$options->{color} = $section->{section_color};
			if ($section && $section->{fsid}) {
				$options->{section} = $section->{fsid};
				$options->{sectionref} = $section;
				$options->{base_filter} = $section->{section_filter};

				my $view = $self->getUserViewById($section->{view_id});

				if ($view && $view->{id}) {
					$opts->{view} = $view->{viewname};
				} else {
					$opts->{view} = "stories";
				}

				$options->{viewref} = $self->getUserViewByName($opts->{view});

				$options = $self->applyViewOptions($options->{viewref}, $options, 1);
				$view_applied = 1;
			}
		} elsif ($form->{view}) {
			my $view = $self->getUserViewByName($form->{view});
			if ($view) {
				$options->{view} = $form->{view};
				$options->{viewref} = $view;
			}
		}

		$options = $self->applyViewOptions($options->{viewref}, $options, 1) if !$view_applied && $options->{viewref};
		$options->{tab} = $form->{tab} if $form->{tab} && !$t_change;
	}

	$options->{global} = $global_opts;
	if ($opts->{initial} && $form->{addfilter}) {
		my $addfilter = $form->{addfilter};
		$addfilter =~ s/[^a-zA-Z0-9]//g;
		$options->{base_filter} .= " $addfilter" if $addfilter;
	}
	$options->{base_filter} =~ s/{nickname}/$user->{nickname}/;
	$options->{fhfilter} = $options->{base_filter};


	my $fhfilter = $options->{base_filter} . " " . $options->{view_filter};

	my $no_saved = $form->{no_saved};
	$opts->{no_set} ||= $no_saved;
	$opts->{initial} ||= 0;

	if (defined $form->{nocommentcnt} && $form->{setfield}) {
		$options->{nocommentcnt} = $form->{nocommentcnt} ? 1 : 0;
	}

	my $mode = $options->{mode};

	if (!$s_change && !$v_change && !$search_trigger) {
		$mode = $form->{mode} || $options->{mode} || '';
	}

	my $pagesize;
	$pagesize = $options->{pagesize} = $validator->{pagesizes}{$options->{pagesize}} ? $options->{pagesize} : "small";

	if (!$s_change && !$v_change && !$search_trigger) {
		$options->{mode} = $s_change ? $options->{mode} : $mode;
	}

	$form->{pause} = 1 if $no_saved;

	my $firehose_page = $user->{state}{firehose_page} || '';

	if (!$v_change && !$s_change && !$search_trigger) {
		if (defined $form->{duration}) {
			if ($form->{duration} =~ /^-?\d+$/) {
				$options->{duration} = $form->{duration};
			}
		}
		$options->{duration} = "-1" if !$options->{duration};

		if (defined $form->{startdate}) {
			if ($form->{startdate} =~ /^\d{8}$/) {
				my($y, $m, $d) = $form->{startdate} =~ /(\d{4})(\d{2})(\d{2})/;
				if ($y) {
					$options->{startdate} = "$y-$m-$d";
				}
			} else {
				$options->{startdate} = $form->{startdate};
			}
		}
		$options->{startdate} = "" if !$options->{startdate};
		if ($form->{issue}) {
			if ($form->{issue} =~ /^\d{8}$/) {
				my($y, $m, $d) = $form->{issue} =~ /(\d{4})(\d{2})(\d{2})/;
				$options->{startdate} = "$y-$m-$d";
				$options->{issue} = $form->{issue};
				$options->{duration} = 1;

			} else {
				$form->{issue} = "";
			}
		}
	}


	my $colors = $self->getFireHoseColors();
	if ($form->{color} && $validator->{colors}->{$form->{color}} && !$s_change && !$v_change) {
		$options->{color} = $form->{color};
	}

	if ($form->{orderby}) {
		if ($form->{orderby} eq "popularity") {
			if ($user->{is_admin} && !$options->{usermode}) {
				$options->{orderby} = 'editorpop';
			} else {
				$options->{orderby} = 'popularity';
			}
		} elsif ($form->{orderby} eq 'neediness') {
			$options->{orderby} = 'neediness';
		} else {
			$options->{orderby} = "createtime";
		}

	} else {
		$options->{orderby} ||= 'createtime';
	}

	if ($form->{orderdir}) {
		if (uc($form->{orderdir}) eq "ASC") {
			$options->{orderdir} = "ASC";
		} else {
			$options->{orderdir} = "DESC";
		}

	} else {
		$options->{orderdir} ||= 'DESC';
	}

	if ($opts->{initial}) {
		if (!defined $form->{section}) {
			#$form->{section} = $gSkin->{skid} == $constants->{mainpage_skid} ? 0 : $gSkin->{skid};
		}
	}

	my $the_skin = defined $form->{section} ? $self->getSkin($form->{section}) : $gSkin;


	#my $skin_prefix="";
	#if ($the_skin && $the_skin->{name} && $the_skin->{skid} != $constants->{mainpage_skid})  {
	#	$skin_prefix = "$the_skin->{name} ";
	#}

	#$user_tabs = $self->genUntitledTab($user_tabs, $options);


	foreach (qw(nodates nobylines nothumbs nocolors noslashboxes nomarquee)) {
		if ($form->{setfield}) {
			if (defined $form->{$_}) {
				$options->{$_} = $form->{$_} ? 1 : 0;
			}
		}
	}

	$options->{smalldevices} = 1 if $self->shouldForceSmall();
	$options->{limit} = $self->getFireHoseLimitSize($options->{mode}, $pagesize, $options->{smalldevices}, $options);

	my $page = $options->{page} = $form->{page} || 0;
	if ($page) {
		$options->{offset} = $page * $options->{limit};
	}


	$fhfilter =~ s/^\s+|\s+$//g;

	$options->{user_view_uid} = $opts->{user_view}{uid} || $form->{user_view_uid};
	if ($fhfilter =~ /\{nickname\}/) {
		if (!$opts->{user_view}) {
			if ($form->{user_view_uid}) {
				$opts->{user_view} = $self->getUser($form->{user_view_uid}) || $user;
			} else {
				$opts->{user_view} = $user;
			}
		}
		my $the_nickname = $opts->{user_view}{nickname};

		$fhfilter =~ s/\{nickname\}/$the_nickname/g;
		$options->{fhfilter} =~ s/\{nickname\}/$the_nickname/g;
		$options->{base_filter} =~ s/\{nickname\}/$the_nickname/g;
	}

	if ($fhfilter =~ /\{tag\}/) {
		my $the_tag = $opts->{tag} || $form->{tagname};
		$fhfilter =~ s/\{tag\}/$the_tag/g;
		$options->{fhfilter} =~ s/\{tag\}/$the_tag/g;
		$options->{base_filter} =~ s/\{tag\}/$the_tag/g;
	}

	my $fh_ops = $self->splitOpsFromString($fhfilter);

	my $skins = $self->getSkins();
	my %skin_nexus = map { $skins->{$_}{name} => $skins->{$_}{nexus} } keys %$skins;

	my $fh_options = {};



	foreach (@$fh_ops) {
		my $not = "";
		if (/^-/) {
			$not = "not_";
			$_ =~ s/^-//g;
		}
		if ($validator->{type}->{$_}) {
			push @{$fh_options->{$not."type"}}, $_;
		} elsif ($user->{is_admin} && $validator->{categories}{$_} && !defined $fh_options->{category}) {
			$fh_options->{category} = $_;
		} elsif ($skin_nexus{$_}) {
			push @{$fh_options->{$not."nexus"}}, $skin_nexus{$_};
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
		} elsif (/^authorfriend:(.*)$/ && $constants->{plugin}{Zoo}) {
			my $uid;
			my $nick = $1;
			if ($nick) {
				$uid = $self->getUserUID($nick);
				$uid ||= $user->{uid};
			}
			my $zoo = getObject("Slash::Zoo");
			my $friends = $zoo->getFriendsUIDs($uid);
			$friends = [-1], if @$friends < 1;   # No friends, pass a UID that won't match
			push @{$fh_options->{$not."uid"}}, @$friends;
		} elsif (/^(user|home|hose):/) {
			my $type = $1;
			(my $nick = $_) =~ s/^$type://;
			my $uid;
			$uid = $self->getUserUID($nick) if $nick;
			$uid ||= $user->{uid};
			$fh_options->{tagged_by_uid} = [$uid];
			if ($type eq 'user') {
				$fh_options->{tagged_non_negative} = 1;
#				$fh_options->{ignore_nix} = 1;
			} elsif ($type eq 'home') {
				$fh_options->{tagged_for_homepage} = 1;
			} elsif ($type eq 'hose') {
				$fh_options->{tagged_non_negative} = 1;
				my $zoo = getObject("Slash::Zoo");
				my $friends = $zoo->getFriendsUIDs($uid);
				push @{$fh_options->{tagged_by_uid}}, @$friends;
			}
		} elsif (/^tag:/) {
			my $tag = $_;
			$tag =~s/tag://g;
			$fh_options->{tagged_as} = $tag;
		} else {
			my $filter_word = $_;
			$filter_word =~ s/[^a-zA-Z0-9_-]+//g;
			$filter_word = "-" . $filter_word if $not;
			$fh_options->{filter} .= "$filter_word ";

			# Don't filter this
			$fh_options->{qfilter} .= $_ . ' ';
			$fh_options->{qfilter} = '-' . $fh_options->{qfilter} if $not;
		}
	}

	# push all necessary nexuses on if we want stories show as brief
	if ($constants->{brief_sectional_mainpage} && $options->{viewref}{viewname} eq 'stories') {
		if (!$fh_options->{nexus}) {
			my $nexus_children = $self->getMainpageDisplayableNexuses();
			push @{$fh_options->{nexus}}, @$nexus_children, $constants->{mainpage_nexus_tid};

			if ($user->{index_classic} && $user->{story_never_nexus}) {
				push @{$fh_options->{not_nexus}}, (split /,/, $user->{story_never_nexus});
			}

			$fh_options->{offmainpage} = "no";
			$fh_options->{stories_mainpage} = 1;
		} else {
			$fh_options->{stories_sectional} = 1;
		}
	}
	# Pull out any excluded nexuses we're explicitly asking for

	if ($fh_options->{nexus} && $fh_options->{not_nexus}) {
		my %not_nexus = map { $_ => 1 } @{$fh_options->{not_nexus}};
		@{$fh_options->{nexus}} = grep { !$not_nexus{$_} } @{$fh_options->{nexus}};
		delete $fh_options->{nexus} if @{$fh_options->{nexus}} == 0;
	}

	my $color = (defined $form->{color} && !$s_change && !$v_change) && $validator->{colors}->{$form->{color}} ? $form->{color} : "";
	$color = defined $options->{color} && $validator->{colors}->{$options->{color}} ? $options->{color} : "" if !$color;

	$fh_options->{color} = $color;


	foreach (keys %$fh_options) {
		$options->{$_} = $fh_options->{$_};
	}

	my $adminmode = 0;
	$adminmode = 1 if $user->{is_admin};
	if ($no_saved) {
		$adminmode = 0;
	} elsif (defined $options->{usermode}) {
		$adminmode = 0 if $options->{usermode};
	}

	$options->{public} = "yes";

	if (!$options->{usermode} && $user->{is_admin}) {
		$options->{admin_filters} = 1;
	}

	if ($adminmode) {
		# $options->{attention_needed} = "yes";
		if ($options->{admin_filters}) {
			$options->{accepted} = "no" if !$options->{accepted};
			$options->{rejected} = "no" if !$options->{rejected};
		}
		$options->{duration} ||= -1;
	} else  {
		if ($firehose_page ne "user") {
			# $options->{accepted} = "no" if !$options->{accepted};
		}

		if ($user->{is_subscriber} && (!$no_saved || $form->{index})) {
			$options->{createtime_subscriber_future} = 1;
		} else {
			$options->{createtime_no_future} = 1;
		}
	}

	if ($options->{issue}) {
		$options->{duration} = 1;
	}

	$options->{not_id} = $opts->{not_id} if $opts->{not_id};
	if ($form->{not_id} && $form->{not_id} =~ /^\d+$/) {
		$options->{not_id} = $form->{not_id};
	}


	if ($v_change) {
		$options->{section} = $form->{section};
		if ($form->{section}) {
			$options->{sectionref} = $self->getFireHoseSection($form->{section});
		}
		$self->applyViewOptions($options->{viewref}, $options, 1);
	}

	if ($form->{index}) {
		$options->{index} = 1;
		$options->{skipmenu} = 1;

		if ($options->{stories_mainpage}) {
			if (!$form->{issue}) {
				$options->{duration} = "-1";
				$options->{mode} = "mixed";
			}
		}

		if ($options->{stories_sectional}) {
			$options->{duration} = "-1";
			$options->{mode} = 'full';
		}
	}

	if ($form->{more_num} && $form->{more_num} =~ /^\d+$/) {
		$options->{more_num} = $form->{more_num};
		if (!$user->{is_admin} && (($options->{limit} + $options->{more_num}) > 200)) {
			$options->{more_num} = 200 - $options->{limit} ;
		}
		if (!$user->{is_anon} && $options->{more_num} > $user->{firehose_max_more_num}) {
			$self->setUser($user->{uid}, { firehose_max_more_num => $options->{more_num}});
		}
	}

	if ($options->{viewref} && $options->{viewref}{viewtitle}) {
		if ($options->{viewref}{viewtitle} =~ /{nickname}/) {
			my $nick_user = $options->{user_view_uid} || $user->{uid};
			my $nick = $self->getUser($nick_user, 'nickname');
			$options->{viewref}{viewtitle} =~ s/\{nickname\}/$nick/;
		}
		$options->{viewtitle} = $options->{viewref}{viewtitle};
	}
	if ($options->{sectionref} && $options->{sectionref}{section_name}) {
		$options->{sectionname} = $options->{sectionref}{section_name};
	}

	$options->{fhfilter} =~ s/{nickname}/$nick_user->{nickname}/g;
	$options->{base_filter} =~ s/{nickname}/$nick_user->{nickname}/g;
	$options->{view_filter} =~ s/{nickname}/$nick_user->{nickname}/g;

#use Data::Dumper;
#print STDERR Dumper($options);
#print STDERR "TEST: BASE_FILTER $options->{base_filter}   FHFILTER: $options->{fhfilter} VIEW $options->{view} VFILTER: $options->{view_filter} TYPE: " . Dumper($options->{type}). "\n";
#print STDERR "FHFILTER: $options->{fhfilter} NEXUS: " . Dumper($options->{nexus}) . "\n";
#print STDERR "VIEW: $options->{view} MODE: $mode USERMODE: |$options->{usermode}  UNSIGNED: $options->{unsigned} PAUSE $options->{pause} FPAUSE: |$form->{pause}|\n";
#print STDERR "DURATION $options->{duration} STARTDATE: $options->{startdate}\n";
#print STDERR "VIEW: $options->{view} COLOR: $options->{color}\n";
	slashProf("","fh_gASO");
	return $options;
}

sub getFireHoseLimitSize {
	my($self, $mode, $pagesize, $forcesmall, $options) = @_;
	$pagesize ||= '';

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $limit;

	my $pagesizes = {
		single	=> [1,1,1],
		tiny	=> [5,5,5],
		small	=> [10,10,20],
		large	=> [15,20,30],
		huge	=> [50,50,50],
	};

	$pagesize ||= "small";
	if ($forcesmall) {
		$pagesize = "tiny";
	}

	my $mode_map = { full => 0, mixed => 1, fulltitle => 2 };

	my $mode_id = $mode_map->{$mode};

	$limit = $pagesizes->{$pagesize}[$mode_id];

	$limit ||= 10;

	$limit = 15 if $options->{view} =~ /^user/ && $limit >= 15;
	$limit = 10 if $form->{metamod};

	return $limit;
}

sub shouldForceSmall {
	my($self) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	# the non-normal cases: a small device (e.g., iPhone) or an embedded use (e.g., Google Gadget)
	my $force_smaller = $form->{embed} ? 1 : 0;
	$force_smaller = 1 if $user->{state}{smalldevice};
	return $force_smaller;
}

sub getInitTabtypeOptions {
	my($self, $name) = @_;
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $vol = $self->getSkinVolume($gSkin->{skid});
	my $day_specified = $form->{startdate} || $form->{issue};
	my $set_option;

	$vol ||= { story_vol => 0, other_vol => 0};

	if ($name eq "tabsection") {
		if ($gSkin->{skid} == $constants->{mainpage_skid}) {
			$set_option->{mixedmode} = "1";
		}
		$set_option->{mode} = "full";
		if (!$day_specified) {
			if ($vol->{story_vol} > 25) {
				$set_option->{duration} = 7;
			} else {
				$set_option->{duration} = -1;
			}
			$set_option->{startdate} = "";
		}
	} elsif (($name eq "tabpopular" || $name eq "tabrecent") && !$day_specified) {
		if ($vol->{story_vol} > 25) {
			$set_option->{duration} = 7;
		} else {
			$set_option->{duration} = -1;
		}
		$set_option->{startdate} = "";
		$set_option->{mixedmode} = "1";
	} elsif ($name eq "metamod") {
		$set_option->{duration} = 7;
		$set_option->{startdate} = '';
	}
	return $set_option;
}
sub getFireHoseSystemTags {
	my($self, $item) = @_;
	my $constants = getCurrentStatic();
	my @system_tags;
	push @system_tags, $item->{type};
	if ($item->{primaryskid}) {
		if ($item->{primaryskid} == $constants->{mainpage_skid}) {
			push @system_tags, "mainpage";
		} else {
			my $the_skin = $self->getSkin($item->{primaryskid});
			push @system_tags, "$the_skin->{name}";
		}
	}
	if ($item->{tid}) {
		my $the_topic = $self->getTopic($item->{tid});
		push @system_tags, "$the_topic->{keyword}";
	}
	return join ' ', @system_tags;
}
sub getFireHoseTagsTop {
	my($self, $item) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $form = getCurrentForm();
	my $tags_top	 = [];

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

	if ($item->{primaryskid}) {
		if ($item->{primaryskid} == $constants->{mainpage_skid}) {
			push @$tags_top, "mainpage:2";
		} else {
			my $the_skin = $self->getSkin($item->{primaryskid});
			push @$tags_top, "$the_skin->{name}:2";
		}
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
			$#$user_tags_top = 2;
		}
	}

	if ($form->{embed}) {
		$#$user_tags_top = 2;
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

	slashProfInit();
	slashProf("fh_listview");

	$lv_opts ||= {};
	$lv_opts->{initial} = 1;

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();

	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $featured;

	if ($gSkin->{name} eq "idle" && !$user->{firehose_nomarquee}) {
		my $featured_ops = { primaryskid => $gSkin->{skid}, type => "story", limit => 1, orderby => 'createtime', orderdir => 'DESC'};

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
	$lv_opts->{fh_page} ||= "firehose.pl";
	my $base_page = $lv_opts->{fh_page};
	my $options = $self->getAndSetOptions($lv_opts);

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

	if ($options->{orderby} eq "createtime" && !$options->{spritegen}) {
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
	my $vol = $self->getSkinVolume($gSkin->{skid});
	$vol->{story_vol} ||= 0;
	if ($vol->{story_vol} < 25) {
		$mixed_abbrev_pop = $self->getMinPopularityForColorLevel(3);
	}
	my $constants = getCurrentStatic();

	foreach (@$items) {
		if ($options->{mode} eq "mixed") {
			$curmode = "full";
			$curmode = "fulltitle" if $_->{popularity} < $mixed_abbrev_pop;

		}
		$maxtime = $_->{createtime} if $_->{createtime} gt $maxtime && $_->{createtime} lt $now;
		my $item =  $firehose_reader->getFireHose($_->{id});
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		my $tags = getObject("Slash::Tags", { db_type => 'reader' })->setGetCombinedTags($_->{id}, 'firehose-id');
		if ($_->{day}) {
			my $day = $_->{day};
			$day =~ s/ \d{2}:\d{2}:\d{2}$//;
			$itemstext .= slashDisplay("daybreak", { options => $options, cur_day => $day, last_day => $_->{last_day}, id => "firehose-day-$day", fh_page => $base_page }, { Return => 1, Page => "firehose" });
		} else {
	$last_day = timeCalc($item->{createtime}, "%Y%m%d");
			slashProf("firehosedisp");
			$itemstext .= $self->dispFireHose($item, {
				mode			=> $curmode,
				tags_top		=> $tags_top,		# old-style
				top_tags		=> $tags->{top},	# new-style
				system_tags		=> $tags->{'system'},	# new-style
				datatype_tags		=> $tags->{'datatype'},	# new-style
				options			=> $options,
				vote			=> $votes->{$item->{globjid}},
				bodycontent_include	=> $user->{is_anon}
			});
			slashProf("","firehosedisp");
		}
		$i++;
	}
	my $Slashboxes = "";
	if ($user->{state}{firehose_page} eq "console") {
		my $console = getObject("Slash::Console");
		$Slashboxes = $console->consoleBoxes();;
	} else {
		$Slashboxes = displaySlashboxes($gSkin);
	}
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

	my $views = $self->getUserViews({ tab_display => "yes"});

	my $ret = slashDisplay("list", {
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
		firehose_more_data 	=> $firehose_more_data,
		views			=> $views,
		theupdatetime		=> timeCalc($slashdb->getTime(), "%H:%M"),
	}, { Page => "firehose", Return => 1 });

	slashProf("","fh_listview");
	slashProfEnd("FH_LISTVIEW");
	return $ret;

}

sub setFireHoseSession {
	my($self, $id, $action) = @_;
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

sub getUserTabByName {
	my($self, $name, $options) = @_;
	$options ||= {};
	my $user = getCurrentUser();
	my $uid_q = $self->sqlQuote($user->{uid});
	my $tabname_q = $self->sqlQuote($name);
	return $self->sqlSelectHashref("*", "firehose_tab", "uid=$uid_q && tabname=$tabname_q");
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
	my($self, $str) = @_;
	my @fh_ops_orig = map { lc($_) } split(/(\s+|")/, $str);
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

{
my %last_levels;
sub addDayBreaks {
	my($self, $items, $offset, $options) = @_;
	my $retitems = [];
	my $breaks = 0;

	my $level = $options->{level} || 0;
	my $count = @$items;
	my $break_ratio = 5;
	my $max_breaks = ceil($count / $break_ratio);

	my($db_levels, $db_order) = getDayBreakLevels();
	my $fmt = $db_levels->{ $db_order->[$level] }{fmt};

	my $last_level = $last_levels{$level} ||= timeCalc('1970-01-01 00:00:00', $fmt, 0);

	foreach (@$items) {
		my $cur_level = timeCalc($_->{createtime}, $fmt, $offset);
		if ($cur_level ne $last_level) {
			if ($last_level ne $last_levels{$level}) {
				push @$retitems, { id => "day-$cur_level", day => $cur_level, last_day => $last_level };
				$breaks++;
			}
		}

		push @$retitems, $_;
		$last_level = $cur_level;
	}

	if ($level < $#{$db_order}) {
		my $newitems = addDayBreaks($self, $items, $offset,
			{ level => $level+1 }
		);
#printf STDERR "daybreak levels: %s, breaks: %s, count: %s, maxbreaks: %s, existing: %s, new: %s\n",
#	$db_order->[$level], $breaks, $count, $max_breaks,
#	scalar(@$newitems), scalar(@$retitems);

		$retitems = $newitems if (
			$breaks > $max_breaks
				||
			@$newitems >= @$retitems
		);

	}

	return $retitems;
}}

# deprecated, i think -- pudge 2009-02-17
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
		my($ny, $nm, $nd) = Add_Delta_YMD($y, $m, $d, 0, $_, 0);
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

	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });

	my $downlabel = $constants->{tags_downvote_tagname} || 'nix';
	my $down_id = $tags_reader->getTagnameidFromNameIfExists($downlabel);

	my $uplabel = $constants->{tags_upvote_tagname} || 'nod';
	my $up_id = $tags_reader->getTagnameidFromNameIfExists($uplabel);
	my $data = {};

#	$data->{fh_users} = $tags_reader->sqlSelect("COUNT(DISTINCT uid)", "tags",
#		"tagnameid IN ($up_id, $down_id)");
	my $d_clause = " AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)";
	my $h_clause = " AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)";
	$data->{fh_users_day} = $tags_reader->sqlSelect("COUNT(DISTINCT uid)", "tags",
		"tagnameid IN ($up_id, $down_id) $d_clause");
	$data->{fh_users_hour} = $tags_reader->sqlSelect("COUNT(DISTINCT uid)", "tags",
		"tagnameid IN ($up_id, $down_id) $h_clause");
	$data->{tag_cnt_day} = $tags_reader->sqlSelect("COUNT(*)", "tags,users,firehose",
		"firehose.globjid=tags.globjid AND tags.uid=users.uid AND users.seclev = 1 $d_clause");
	$data->{tag_cnt_hour} = $tags_reader->sqlSelect("COUNT(*)", "tags,users,firehose",
		"firehose.globjid=tags.globjid AND tags.uid=users.uid AND users.seclev = 1 $h_clause");
	$data->{nod_cnt_day} = $tags_reader->sqlSelect("COUNT(*)", "tags,users",
		"tags.uid=users.uid AND users.seclev = 1 AND tagnameid IN ($up_id) $d_clause");
	$data->{nod_cnt_hour} = $tags_reader->sqlSelect("COUNT(*)", "tags,users",
		"tags.uid=users.uid AND users.seclev = 1 AND tagnameid IN ($up_id) $h_clause");
	$data->{nix_cnt_day} = $tags_reader->sqlSelect("COUNT(*)", "tags,users",
		"tags.uid=users.uid AND users.seclev = 1 AND tagnameid IN ($down_id) $d_clause");
	$data->{nix_cnt_hour} = $tags_reader->sqlSelect("COUNT(*)", "tags,users",
		"tags.uid=users.uid AND users.seclev = 1 AND tagnameid IN ($down_id) $h_clause");
	$data->{globjid_cnt_day} = $tags_reader->sqlSelect("COUNT(DISTINCT globjid)", "tags,users",
		"tags.uid=users.uid AND users.seclev = 1 AND tagnameid IN ($up_id, $down_id) $d_clause");
	$data->{globjid_cnt_hour} = $tags_reader->sqlSelect("COUNT(DISTINCT globjid)", "tags,users",
		"tags.uid=users.uid AND users.seclev = 1 AND tagnameid IN ($up_id, $down_id) $h_clause");

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

	my $linktitle = $item->{title};
	$linktitle =~ s/\s+/-/g;
	$linktitle =~ s/[^A-Za-z0-9\-]//g;

	if ($item->{type} eq "story") {
		my $story = $self->getStory($item->{srcid});
		unless ($constants->{firehose_link_article2}) {
			my $story_link_ar = linkStory({
				sid	=> $story->{sid},
				link 	=> $story->{title},
				tid 	=> $story->{tid},
				skin	=> $story->{primaryskid}
			}, 0);
			$link_url = $story_link_ar->[0];
		} else {
			my $story_skin = $self->getSkin($story->{primaryskid});
			$link_url = "$story_skin->{rootdir}/story/$story->{sid}/$linktitle";
		}
	} elsif ($item->{type} eq "journal") {
		my $the_user = $self->getUser($item->{uid});
		my $rootdir = $constants->{real_rootdir};
		if ($the_user->{shill_id}) {
			my $shill = $self->getShillInfo($the_user->{shill_id});
			if ($shill->{skid}) {
				my $shill_skin = $self->getSkin($shill->{skid});
				$rootdir = $shill_skin->{rootdir};
			}
			$link_url = $rootdir . "/journal/$item->{srcid}/$linktitle";
		} else {
			$link_url = $rootdir . "/~" . fixparam($the_user->{nickname}) . "/journal/$item->{srcid}";
		}

	} elsif ($item->{type} eq "comment") {
		my $com = $self->getComment($item->{srcid});
		$link_url = $gSkin->{rootdir} . "/comments.pl?sid=$com->{sid}&amp;cid=$com->{cid}";
	} elsif ($item->{type} eq "submission") {
		$link_url = $gSkin->{rootdir} . "/submission/$item->{srcid}/$linktitle";
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
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$data ||= {};
	my @params;

	my $params = {
		fhfilter        => 0,
		issue           => 1,
		startdate       => 1,
		duration        => 1,
		index           => 1,
		view            => 1,
		color		=> 1
	};
	if ($user->{is_anon}) {
		my($label, $value) = @_;
		if ($options->{sel_tabtype} || $form->{tabtype}) {
			$label = "tabtype";
			$value = $form->{tabtype} || $options->{sel_tabtype};
			$value = strip_paramattr($value);
			push @params, "$label=$value";
		}
		$value = strip_paramattr($form->{section});
		$label = "section";
		push @params, "$label=$value";
	}

	my $skip_false = { startdate => 1, issue => 1 };

	foreach my $label (keys %$params) {
		next if $skip_false->{$label} && !$data->{$label} && !$options->{$label};
		next if $user->{is_anon} && $params->{$label} == 0;
		next if !defined $data->{$label} && !defined $options->{$label};
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

sub getSkinVolume {
	my($self, $skid) = @_;
	my $skid_q = $self->sqlQuote($skid);
	return $self->sqlSelectHashref("*", "firehose_skin_volume", "skid=$skid_q");
}

sub genFireHoseWeeklyVolume {
	my($self, $options) = @_;
	$options ||= {};
	my $colors = $self->getFireHoseColors();
	my @where;

	if ($options->{type}) {
		push @where, "type=" . $self->sqlQuote($options->{type});
	}
	if ($options->{not_type}) {
		push @where, "type!=" . $self->sqlQuote($options->{not_type});
	}
	if ($options->{color}) {
		my $pop;
		$pop = $self->getMinPopularityForColorLevel($colors->{$options->{color}});
		push @where, "popularity >= " . $self->sqlQuote($pop);
	}
	if ($options->{primaryskid}) {
		push @where, "primaryskid=" . $self->sqlQuote($options->{primaryskid});
	}
	push @where, "createtime >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
	my $where = join ' AND ', @where;
	return $self->sqlCount("firehose", $where);
}

sub setSkinVolume {
	my($self, $data) = @_;
	$self->sqlReplace("firehose_skin_volume", $data);
}

sub getProjectsChangedSince {
	my($self, $ts, $options) = @_;
	my $ts_q = $self->sqlQuote($ts);
	if ($ts =~ /^\d+$/) {
		#convert from unixtime if necessary
		$ts = $self->sqlSelect("from_unixtime($ts)");
	}
	$ts_q = $self->sqlQuote($ts);
	my $max_num = defined($options->{max_num}) ? $options->{max_num} : 10;

	my $hr_ar = $self->sqlSelectAllHashrefArray(
		'firehose.id AS firehose_id, firehose.globjid, firehose.toptags, discussions.commentcount, GREATEST(firehose.last_update, discussions.last_update) AS last_update, unixname AS name',
		'firehose, discussions, projects',
		"firehose.type='project'
		 AND firehose.discussion = discussions.id
		 AND projects.id = firehose.srcid
		 AND (firehose.last_update >= $ts_q OR discussions.last_update >= $ts_q)",
		"ORDER BY GREATEST(firehose.last_update, discussions.last_update) ASC
		 LIMIT $max_num");
	$self->addGlobjEssentialsToHashrefArray($hr_ar);

	return $hr_ar;
}

sub createSprite {
	my($self, $fhid, $options) = @_;

	my $constants = getCurrentStatic();
	my $convert = $constants->{imagemagick_convert};
	my $convert_ops = ' -background none -mosaic -bordercolor none -border 0x0 -quality 100 -depth 8';
	my $convert_image_ops = '';
	my $border = 50;
	my $x_offset = 0;
	my $y_offset = 0;
	my $output_file = $fhid . '.png';
	my $image_ar = $self->getSpriteInfo($fhid);

	# Build the param list to convert.
	foreach my $image (@$image_ar) {
		$convert_image_ops .= " -page +0+$y_offset " . $image->{file};
		$image->{x_coord} = $x_offset;
		$image->{y_coord} = $y_offset;
		$image->{y_coord} = '-' . $image->{y_coord} if ($image->{y_coord});
		($image->{raw_filename}) = $image->{file} =~ m{^.+/(.+)\.\w{3}$};
		$y_offset += ($border + $image->{height});
	}

	# Create the dest path.
	my $bd = $constants->{basedir};
	my ($numdir) = sprintf("%09d", $fhid);
	my ($i, $j) = $numdir =~ /(\d\d\d)(\d\d\d)\d\d\d/;
	my $path = catdir($bd, "images", "firehose", $i, $j);
	mkpath($path, 0, 0775);

	# Increment the version number of the sprite.
	my $version = 1;
	if (-s "$path/$output_file") {
		my $sprite_info = $self->sqlSelect('sprite_info', 'firehose', "id = $fhid");
		if ($sprite_info) {
			($version) = $sprite_info =~ m{$output_file\?(\d)};
			++$version;
		}
	}

	# Format CSS
	my $css =
		slashDisplay('format_sprite_info', {
			fhid        => $fhid,
			path        => "firehose/$i/$j",
			sprite_name => $output_file,
			version     => $version,
			images      => $image_ar,
		}, { Page => 'firehose', Return => 1 });

	# Convert and UPDATE
	my $cmd = $convert . $convert_image_ops . $convert_ops . " $path/$output_file";
	system($cmd);

	$self->sqlUpdate('firehose', { sprite => "$i/$j/$output_file", sprite_info => $css }, "id = $fhid");
}

sub getSpriteInfo {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	my $item = $self->getFireHose($id);
	my $opts = { initial => '1'};
	my @images;
	my $basepath = "$constants->{basedir}/images";
	if ($item) {
		if ($item->{type} eq "story") {
			$opts->{view} = "stories";
		} else {
			$opts->{view} = "recent";
		}
		my $options = $self->getAndSetOptions($opts);
		$options->{spritegen} =  1;
		$options->{startdateraw} = $item->{createtime};
		
		# Don't filter out items in the future
		$options->{createtime_no_future} = 0;
		$options->{createtime_subscriber_future} = 0;

		my ($items, $info) = $self->getFireHoseEssentials($options);

                my $i = 0;
                my $seen = {};
                my $key;
                foreach my $it (@$items) {
                        if ($i == 0 && $it->{type} eq "story" && !$it->{thumb}) {
                                my $topiclist = $self->getTopiclistForStory($item->{srcid});
                                foreach (@$topiclist) {
                                        $key = "tid-$_";
                                        my $topic = $self->getTopic($_);
                                        if ($topic->{image}) {
                                                push @images, { label => $key, width => $topic->{width}, height => $topic->{height}, file => "$basepath/topics/$topic->{image}"} if !$seen->{$key};
                                                $seen->{$key}++;
                                        }
                                }
                        }
                        if ($it->{thumb}) {
                                $key = "thumb-$it->{thumb}";
                                my $file = $self->getStaticFile($it->{thumb});
                                push @images, { label => $key, width => $file->{width}, height => $file->{height},  file => "$basepath$file->{name}"} if !$seen->{$key};
                                $seen->{$key}++;
                        } else {
                                $key = "tid-$it->{tid}";
                                my $topic = $self->getTopic($it->{tid});
                                if ($topic->{image}) {
                                        push @images, { label => $key, width => $topic->{width}, height => $topic->{height}, file => "$basepath/topics/$topic->{image}"} if !$seen->{$key};
                                        $seen->{$key}++;
                                }

                        }
                        $i++;
                }
        }
        return \@images;

}

sub getSpriteInfoByFHID {
	my ($self, $fhid, $options) = @_;

	my $sprite = {};
	return {} if !$fhid;

	my $fhid_q = $self->sqlQuote($fhid);
	my $sprite_info = $self->sqlSelect('sprite_info', 'firehose', "id = $fhid_q");

	foreach my $rule ($sprite_info =~ /(\..+?\{.+?\})/g) {
		my ($topic) = $rule =~ /^\.(.+?)\s?\{.+$/;
		$sprite->{$topic} = $rule;
	}

	return  $sprite;
}

1;

__END__


=head1 SEE ALSO

Slash(3).
