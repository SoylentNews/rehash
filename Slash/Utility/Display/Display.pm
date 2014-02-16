# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Utility::Display;

=head1 NAME

Slash::Utility::Display - SHORT DESCRIPTION for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	# do not use this module directly

=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Image::Size;
use Slash::Display;
use Slash::Utility::Data;
use Slash::Utility::Environment;

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(
	cleanSlashTags
	createMenu
	createSelect
	currentAdminUsers
	fancybox
	getImportantWords
	horizmenu
	linkComment
	linkCommentPages
	linkStory
	lockTest
	matchingStrings
	pollbooth
	portalbox
	portalsidebox
	processSlashTags
	selectMode
	selectSection
	selectSortcode
	selectThreshold
	selectTopic
	sidebox
	titlebar
);

#========================================================================

=head2 createSelect(LABEL, DATA [, DEFAULT, RETURN, NSORT, ORDERED, MULTIPLE, ONCHANGE])

Creates a drop-down list in HTML.  List is sorted by default
alphabetically according to list values.

=over 4

=item Parameters

=over 4

=item LABEL

The name/id for the HTML entity.

=item DATA

A hashref containing key-value pairs for the list.
Keys are list values, and values are list labels.
If an arrayref is passed, it is converted to a
hashref, where the keys and values are the same.

=item DEFAULT

Default value for the list.  If MULTIPLE is not set,
this should be the key in DATA that should start out
selected in the popup.  If MULTIPLE is set, this should
be a hashref;  keys which are present and which have
true values will all start out selected in the popup.

If DEFAULT is a hashref, and no other values follow it,
then it is an options hashref, containing possible values
for the keys C<default>, C<return>, C<nsort>, C<ordered>,
C<multiple>, C<onchange>.

=item RETURN

See "Return value" below.

=item NSORT

Boolean: sort numerically, not alphabetically.

=item ORDERED

If an arrayref is passed, an already-sorted array reference of keys.
If non-ref, then an arrayref of hash keys is created sorting the
hash values, alphabetically and case-insensitively.
If ORDERED is passed in either form, then the NSORT parameter is ignored.
### Pudge: would the change below be worth making?  All it would do
### is, in the case where DATA is passed in as an arrayref and the
### desired behavior is to present the items in that order (which
### would probably be typical for callers that pass in an arrayref),
### ORDERED could be passed in as 0 instead of a copy of DATA. -Jamie
#If ORDERED is false, and DATA is passed in a hashref, then its keys are
#sorted in string order.  If ORDERED is false, and DATA is passed in an
#arrayref, then the data is presented in that arrayref's order.

=item MULTIPLE

Boolean: do <SELECT MULTIPLE...> instead of <SELECT...>

=item ONCHANGE

Value for the C<onchange=""> attribute.

=item ONCLICK

Value for the C<onclick=""> attribute.

=back

=item Return value

If RETURN is true, the text of the list is returned.
Otherwise, list is just printed, and returns
true/false if operation is successful.

If there are no elements in DATA, just returns/prints nothing.

=item Dependencies

The 'select' template block.

=back

=cut

sub createSelect {
	my($label, $hashref, $default, $return, $nsort, $ordered, $multiple) = @_;

	my($onchange, $onclick);

	if (ref $default eq 'HASH' && @_ == 3) {
		($default, $return, $nsort, $ordered, $multiple, $onchange, $onclick) =
			@{$default}{qw(default return nsort ordered multiple onchange onclick)};
	}
	$default = '' unless defined $default;

	if (ref $hashref eq 'ARRAY') {
### Pudge: see above. -Jamie
###		if (!$ordered) {
###			# If ORDERED is false, and DATA is passed in an
###			# arrayref, then the data is presented in that
###			# arrayref's order.
###			$ordered = \@{ $hashref };
###		}
		$hashref = { map { ($_, $_) } @$hashref };
	} else {
		# If $hashref is a hash whose elements are also hashrefs, and
		# they all have the field "name", then copy it into another
		# hashref that pulls those "name" fields up one level.  Talk
		# about wacky convenience features!
		my @keys = keys %$hashref;
		my $all_name = 1;
		for my $key (@keys) {
			if (!ref($hashref->{$key})
				|| !ref($hashref->{$key}) eq 'HASH'
				|| !defined($hashref->{$key}{name})) {
				$all_name = 0;
				last;
			}
		}
		if ($all_name) {
			$hashref = {
				map { ($_, $hashref->{$_}{name}) }
				keys %$hashref
			};
		}
	}

	return unless (ref $hashref eq 'HASH' && keys %$hashref);

	if ($ordered && !ref $ordered) {
		$ordered = [
			map  { $_->[0] }
			sort { $a->[1] cmp $b->[1] }
			map  { [$_, lc $hashref->{$_}] }
			keys %$hashref
		];
	}

	my $display = {
		label		=> $label,
		items		=> $hashref,
		default		=> $default,
		numeric		=> $nsort,
		ordered		=> $ordered,
		multiple	=> $multiple,
		onchange	=> $onchange,
		onclick		=> $onclick,
	};

	if ($return) {
		return slashDisplay('select', $display, 1);
	} else {
		slashDisplay('select', $display);
	}
}

#========================================================================

=head2 selectTopic(LABEL [, DEFAULT, SECTION, RETURN])

Creates a drop-down list of topics in HTML.  Calls C<createSelect>.

=over 4

=item Parameters

=over 4

=item LABEL

The name for the HTML entity.

=item DEFAULT

Default topic for the list.

=item SECTION

Default section to take topics from.

=item RETURN

See "Return value" below.

=back

=item Return value

If RETURN is true, the text of the list is returned.
Otherwise, list is just printed, and returns
true/false if operation is successful.

=back

=cut

sub selectTopic {
	my($label, $default, $section, $return) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	# XXXSKIN defaultsection should likely be mainpage_skid, but
	# what of defaulttopic?
	$section ||= getCurrentStatic('defaultsection');
	$default ||= getCurrentStatic('defaulttopic');

	# XXXSKIN this doesn't work to return topics by skin/section
	my $topics = $reader->getDescriptions('non_nexus_topics', $section);

	createSelect($label, $topics, $default, $return, 0, 1);
}

#========================================================================

=head2 selectSection(LABEL [, DEFAULT, SECT, RETURN, ALL])

Creates a drop-down list of sections in HTML.  Calls C<createSelect>.

=over 4

=item Parameters

=over 4

=item LABEL

The name for the HTML entity.

=item DEFAULT

Default topic for the list.

=item SECT

Hashref for current section.

=item RETURN

See "Return value" below.

=item ALL

Boolean for including "All Topics" item.

=back

=item Return value

If RETURN is true, the text of the list is returned.
Otherwise, list is just printed, and returns
true/false if operation is successful.

=back

=cut

sub selectSection {
	my($label, $default, $SECT, $return, $all) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $seclev = getCurrentUser('seclev');
	my $sections = $reader->getDescriptions('sections');

	createSelect($label, $sections, $default, $return);
}

#========================================================================

=head2 selectSortcode()

Creates a drop-down list of sortcodes in HTML.  Default is the user's
preference.  Calls C<createSelect>.

=over 4

=item Return value

The created list.

=back

=cut

sub selectSortcode {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	createSelect('commentsort', $reader->getDescriptions('sortcodes'),
		getCurrentUser('commentsort'), 1);
}

#========================================================================

=head2 selectMode()

Creates a drop-down list of modes in HTML.  Default is the user's
preference.  Calls C<createSelect>.

=over 4

=item Return value

The created list.

=back

=cut

sub selectMode {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	createSelect('mode', $reader->getDescriptions('commentmodes'),
		getCurrentUser('mode'), 1);
}

#========================================================================

=head2 selectThreshold(COUNTS[, OPTIONS])

Creates a drop-down list of thresholds in HTML.  Default is the user's
preference.  Calls C<createSelect()>.

=over 4

=item Parameters

=over 4

=item COUNTS

An arrayref of thresholds -E<gt> counts for that threshold.

=item OPTIONS

Options for C<createSelect()>.

=back

=item Return value

The created list.

=item Dependencies

The 'selectThreshLabel' template block.

=back

=cut

sub selectThreshold  {
	my($counts, $options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my %data;
	foreach my $c ($constants->{comment_minscore} .. $constants->{comment_maxscore}) {
		$data{$c} = slashDisplay('selectThreshLabel', {
			points	=> $c,
			count	=> $counts->[$c - $constants->{comment_minscore}] || 0,
		}, { Return => 1, Nocomm => 1 });
	}

	$options->{default}	= $user->{threshold} unless defined $options->{default};
	$options->{'return'}	= 1                  unless defined $options->{'return'};
	$options->{nsort}	= 1                  unless defined $options->{nsort};

	createSelect('threshold', \%data, $options);
}

#========================================================================

=head2 linkStory(STORY)

The generic "Link a Story" function, used wherever stories need linking.

=over 4

=item Parameters

=over 4

=item STORY

A hashref containing data about a story to be linked to.

=back

=item Return value

The complete E<lt>A HREF ...E<gt>E<lt>/AE<gt> text for linking to the story.

=item Dependencies

The 'linkStory' template block.

=back

=cut

sub linkStory {
	my($story_link, $render, $other) = @_;
	my $reader    = $other->{reader} || getObject('Slash::DB', { db_type => 'reader' });
	my $constants = $other->{constants} || getCurrentStatic();
	my $user      = $other->{user} || getCurrentUser();
	my $gSkin     = getCurrentSkin();

	my($url, $script, $title, %params);
	$script = 'article.pl';
	$params{sid} = $story_link->{sid};
	$params{mode} = $story_link->{mode} if $story_link->{mode};
	$params{threshold} = $story_link->{threshold} if exists $story_link->{threshold};

	# Setting $dynamic properly is important.  When generating the
	# AC index.shtml, it's a big win if we link to other
	# prerendered .shtml URLs whenever possible/appropriate.
	# But, we must link to the .pl when necessary.

	# if we REALLY want dynamic
	my $dynamic = $constants->{article_link_story_dynamic} || $story_link->{dynamic} || 0;
	# takes precedence over dynamic
	my $static  = $story_link->{static}  || 0;

	if (!$static && ($ENV{SCRIPT_NAME} || !$user->{is_anon})) {
		# Whenever we're invoked from Apache, use dynamic links.
		# This test will be true 99% of the time we come through
		# here, so it's first.
		$dynamic = 1;
	} elsif (!$static && $params{mode}) {
		# If we're an AC script, but this is a link to e.g.
		# mode=nocomment, then we need to have it be dynamic.
		$dynamic = 1 if $params{mode} ne getCurrentAnonymousCoward('mode');
	}

	if (!$static && (!$dynamic && defined($params{threshold}))) {
		# If we still think we can get away with a nondynamic link,
		# we need to check one more thing.  Even an AC linking to
		# an article needs to make the link dynamic if it's the
		# "n comments" link, where threshold = -1.  For maximum
		# compatibility we check against the AC's threshold.
		$dynamic = 1 if $params{threshold} != getCurrentAnonymousCoward('threshold');
	}

	my $story_ref = $reader->getStory($story_link->{stoid} || $story_link->{sid});
	$params{sid} ||= $story_ref->{sid};

	if (!defined $story_link->{link} || $story_link->{link} eq '') {
		$story_link->{link} = $story_ref->{title};
	}
	$title = $story_link->{link};
	$story_link->{skin} ||= $story_link->{section} || $story_ref->{primaryskid};
	if ($constants->{tids_in_urls}) {
		if ($story_link->{tids} && @{$story_link->{tids}}) {
			$params{tids} = $story_link->{tids};
		} else {
			$params{tids} = $reader->getTopiclistForStory(
				$story_link->{stoid} || $story_link->{sid} || $story_ref->{sid}
			);
		}
	}

	my $skin = $reader->getSkin($story_link->{skin});
	$url = $skin->{rootdir} || $constants->{real_rootdir} || $gSkin->{rootdir};

	if (!$static && $dynamic) {
		$url .= "/$script?";
		sub _paramsort { return -1 if $a eq 'sid'; return 1 if $b eq 'sid'; $a cmp $b }
		for my $key (sort _paramsort keys %params) {
			my $urlkey = $key;
			$urlkey = 'tid' if $urlkey eq 'tids';
			if (ref $params{$key} eq 'ARRAY') {
				$url .= "$urlkey=$_&" for @{$params{$key}};
			} elsif (defined($params{$key})) {
				$url .= "$urlkey=$params{$key}&";
			}
		}
		chop $url;
	} else {
		# XXXSKIN - hardcode 'articles' so /articles/foo.shtml links stay same as now
		# we don't NEED to do this ... 404.pl can redirect appropriately if necessary,
		# but we would need to `mv articles mainpage`, or ln -s, and it just seems better
		# to me to keep the same URL scheme if possible
		my $skinname = $skin->{name} eq 'mainpage' ? 'articles' : $skin->{name};
		$url .= "/$skinname/" . ($story_link->{sid} || $story_ref->{sid}) . ".shtml";
		# manually add the tid(s), if wanted
		if ($constants->{tids_in_urls} && $params{tids}) {
			$url .= '?';
			if (ref $params{tids} eq 'ARRAY') {
				$url .= 'tid=' . join( "&tid=", map { fixparam($_) } @{$params{tids}} )
					if @{$params{tids}};
			} else {
				$url .= 'tid=' . fixparam($params{tids});
			}
		}
	}

	my @extra_attrs_allowed = qw( title class id );
	if ($render) {
		my $rendered = '<a href="' . strip_attribute($url) . '"';
		for my $attr (@extra_attrs_allowed) {
			my $val = $story_link->{$attr};
			next unless $val;
			$rendered .=
				  qq{ $attr="}
				. strip_attribute($val)
				. qq{"};
		}
		$rendered .= '>' . strip_html($title) . '</a>';
		return $rendered;
	} else {
		return [$url, $title, @{$story_link}{@extra_attrs_allowed}];
	}
}

#========================================================================

=head2 pollbooth(QID [, NO_TABLE, CENTER])

Creates a voting pollbooth.

=over 4

=item Parameters

=over 4

=item QID

The unique question ID for the poll.

=item NO_TABLE

Boolean for whether to leave the poll out of a table.
If false, then will be formatted inside a C<fancybox>.

=item CENTER

Whether or not to center the tabled pollbooth (only
works with NO_TABLE).

=back

=item Return value

Returns the pollbooth data.

=item Dependencies

The 'pollbooth' template block.

=back

=cut

#XXXSKIN getCurrentSkin doesn't seem to be returning anything
# on portald runs.  It defaults to mainpage skid if nothing
# is returned.  However perhaps getCurrentSkin needs more
# attention

sub pollbooth {
	my($qid, $no_table, $center, $fromrss) = @_;
	my $constants = getCurrentStatic();
	return '' if !$constants->{plugin}{PollBooth};
	my $pollbooth_reader = getObject('Slash::PollBooth', { db_type => 'reader' });
	return '' if !$pollbooth_reader;

	my $gSkin = getCurrentSkin();
	# This special qid means to use the current (sitewide) poll.
	if ($qid eq "_currentqid") {
		$qid = $pollbooth_reader->getCurrentQidForSkid($gSkin->{skid});
	}
	
	# If no qid (or no sitewide poll), short-circuit out.
	return '' if !$qid;

	my $poll = $pollbooth_reader->getPoll($qid);
	return '' unless %$poll;

	my $n_comments = $pollbooth_reader->countCommentsBySid(
		$poll->{pollq}{discussion});
	my $poll_open = $pollbooth_reader->isPollOpen($qid);

	return slashDisplay('pollbooth', {
		question	=> $poll->{pollq}{question},
		answers		=> $poll->{answers},
		qid		=> $qid,
		has_activated   => $pollbooth_reader->hasPollActivated($qid),
		poll_open	=> $poll_open,
		voters		=> $poll->{pollq}{voters},
		comments	=> $n_comments,
		fromrss		=> $fromrss,
	}, 1);
}

#========================================================================

=head2 currentAdminUsers()

Displays table of current admin users, with what they are adminning.

=over 4

=item Return value

The HTML to display.

=item Dependencies

The 'currentAdminUsers' template block.

=back

=cut

sub currentAdminUsers {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $now = timeCalc($slashdb->getTime(), "%s", 0);
	my $aids = $slashdb->currentAdmin();
	for my $data (@$aids) {
		my($usernick, $usertime, $lasttitle, $last_subid, $last_sid, $uid) = @$data;
		if ($usernick eq $user->{nickname}) {
			$usertime = "-";
		} else {
			$usertime = $now - timeCalc($usertime, "%s", 0);
			if ($usertime <= 99) {
				$usertime .= "s";
			} elsif ($usertime <= 3600) {
				$usertime = int($usertime/60+0.5) . "m";
			} else {
				$usertime = int($usertime/3600) . "h"
					. int(($usertime%3600)/60+0.5) . "m";
			}
		}
		@$data = ($usernick, $usertime, $lasttitle, $last_subid, $last_sid, $uid);
	}

	my @reader_vus = $slashdb->getDBVUsForType("reader");

	return slashDisplay('currentAdminUsers', {
		ids		=> $aids,
		can_edit_admins	=> $user->{seclev} > 10000,
		reader_vus	=> \@reader_vus,
	}, 1);
}

#========================================================================

=head2 horizmenu()

Silly little function to create a horizontal menu from the
'mainmenu' block.

=over 4

=item Return value

The horizontal menu.

=item Dependencies

The 'mainmenu' template block.

=back

=cut

sub horizmenu {
	my $horizmenu = slashDisplay('mainmenu', {}, { Return => 1, Nocomm => 1 });
	$horizmenu =~ s/^\s*//mg;
	$horizmenu =~ s/^-\s*//mg;
	$horizmenu =~ s/\s*$//mg;
	$horizmenu =~ s/<NOBR>//gi;
	$horizmenu =~ s/<\/NOBR>//gi;
	$horizmenu =~ s#<HR(?:[^>]*>)##gi;
	$horizmenu = join ' | ', split m#<BR(?:[^>]*>)#i, $horizmenu;
	$horizmenu =~ s/[\|\s]+$//;
	$horizmenu =~ s/^[\|\s]+//;
	return "[ $horizmenu ]";
}

#========================================================================

=head2 titlebar(WIDTH, TITLE, OPTIONS)

Prints a titlebar widget.  Exactly equivalent to:

	slashDisplay('titlebar', {
		width	=> $width,
		title	=> $title
	});

or, if template is passed in as an option, e.g. template => user_titlebar:

	slashDisplay('user_titlebar', {
		width	=> $width,
		title	=> $title
	});

If you're calling this from a template, you better have a really good
reason, since [% PROCESS %] will work just as well.

=over 4

=item Parameters

=over 4

=item WIDTH

Width of the titlebar.

=item TITLE

Title of the titlebar.

=back

=item Return value

None.

=item Dependencies

The 'titlebar' template block.

=back

=cut

sub titlebar {
	my($width, $title, $options) = @_;
	my $templatename = $options->{template} ? $options->{template} : "titlebar";
	my $data = { width => $width, title => $title };
	$data->{tab_selected} = $options->{tab_selected} if $options->{tab_selected};
	slashDisplay($templatename, $data);
}

#========================================================================

=head2 fancybox(WIDTH, TITLE, CONTENTS [, CENTER, RETURN])

Creates a fancybox widget.

=over 4

=item Parameters

=over 4

=item WIDTH

Width of the fancybox.

=item TITLE

Title of the fancybox.

=item CONTENTS

Contents of the fancybox.  (I see a pattern here.)

=item CENTER

Boolean for whether or not the fancybox
should be centered.

=item RETURN

Boolean for whether to return or print the
fancybox.

=item CLASS

Value of the HTML 4.0 and up CLASS attribute.

=item ID

Value of the HTML 4.0 and up ID attribute.

=back

=item Return value

The fancybox if RETURN is true, or true/false
on success/failure.

=item Dependencies

The 'fancybox' template block.

=back

=cut

sub fancybox {
	my($width, $title, $contents, $center, $return, $class, $id) = @_;
	return '' unless $title && $contents;

	slashDisplay('fancybox', {
		width		=> $width,
		contents	=> $contents,
		title		=> $title,
		center		=> $center,
		class           => $class,
		id              => $id,
	}, $return);
}

sub sidebox {
	my ($title, $contents, $name, $return) = @_;
	return '' unless $title && $contents;
	slashDisplay('sidebox', {
		contents	=> $contents,
		title		=> $title,
		name            => $name,
	}, $return);
}

#========================================================================

=head2 portalbox(WIDTH, TITLE, CONTENTS, BID [, URL])

Creates a portalbox widget.  Calls C<fancybox> to process
the box itself.

=over 4

=item Parameters

=over 4

=item WIDTH

Width of the portalbox.

=item TITLE

Title of the portalbox.

=item CONTENTS

Contents of the portalbox.

=item GETBLOCKS

If set to 'index' (or blank), adds the down/X/up arrows to the
right hand side of the portalbox title (displayed only on an
index page).

=item BID

The block ID for the portal in question.

=item URL

URL to link the title of the portalbox to.

=back

=item Return value

The portalbox.

=item Dependencies

The 'fancybox', 'portalboxtitle', and
'portalmap' template blocks.

=back

=cut

sub portalbox {
	my($width, $title, $contents, $bid, $url, $getblocks, $class, $id) = @_;
	return '' unless $title && $contents;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$getblocks ||= 'index';

	$title = slashDisplay('portalboxtitle', {
		title	=> $title,
		url	=> $url,
	}, { Return => 1, Nocomm => 1 });

	if (
		   ($user->{slashboxes} && $getblocks == $constants->{mainpage_skid})
		|| ($user->{slashboxes} && $constants->{slashbox_sections})
	) {
		$title = slashDisplay('portalmap', {
			title	=> $title,
			bid	=> $bid,
		}, { Return => 1, Nocomm => 1 });
	}

	fancybox($width, $title, $contents, 0, 1, $class, $id);
}

sub portalsidebox {
	my($title, $contents, $bid, $url, $getblocks, $name) = @_;
	return '' unless $title && $contents;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$getblocks ||= 'index';

	$title = slashDisplay('portalboxtitle', {
		title	=> $title,
		url	=> $url,
	}, { Return => 1, Nocomm => 1 });

	if (
		   ($user->{slashboxes} && $getblocks == $constants->{mainpage_skid})
		|| ($user->{slashboxes} && $constants->{slashbox_sections})
	) {
		$title = slashDisplay('portalmap', {
			title	=> $title,
			bid	=> $bid,
		}, { Return => 1, Nocomm => 1 });
	}
	$name ||= $bid;

	sidebox($title, $contents, $name, 1);
}

#========================================================================

=head2 linkCommentPages(SID, PID, CID, TOTAL)

Print links to pages for additional comments.

=over 4

=item Parameters

=over 4

=item SID

Story ID.

=item PID

Parent ID.

=item CID

Comment ID.

=item TOTAL

Total number of comments.

=back

=item Return value

Links.

=item Dependencies

The 'linkCommentPages' template block.

=back

=cut

sub linkCommentPages {
	my($sid, $pid, $cid, $total) = @_;

	return slashDisplay('linkCommentPages', {
		sid	=> $sid,
		pid	=> $pid,
		cid	=> $cid,
		total	=> $total,
	}, 1);
}

#========================================================================

=head2 linkComment(COMMENT [, PRINTCOMMENT, DATE])

Print a link to a comment.

=over 4

=item Parameters

=over 4

=item COMMENT

A hashref containing data about the comment.

=item PRINTCOMMENT

Boolean for whether to create link directly
to comment, instead of to the story for that comment.

=item DATE

Boolean for whather to print date with link.

=back

=item Return value

Link for comment.

=item Dependencies

The 'linkComment' template block.

=back

=cut

sub linkComment {
	my($linkdata, $printcomment, $options) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $adminflag = $user->{seclev} >= 10000 ? 1 : 0;

	# don't inherit these ...
	for (qw(sid cid pid date subject comment uid points lastmod
		reason nickname fakeemail homepage sig)) {
		$linkdata->{$_} = undef unless exists $linkdata->{$_};
	}

	$linkdata->{pid}     = $linkdata->{original_pid} || $linkdata->{pid};
	$linkdata->{comment} = $printcomment;

	if (!$options->{noextra}) {
		%$linkdata = (%$linkdata,
			adminflag	=> $adminflag,
			date		=> $options->{date},
			threshold	=> defined($linkdata->{threshold}) ? $linkdata->{threshold} : $user->{threshold},
			commentsort	=> $user->{commentsort},
			mode		=> $user->{mode},
		);
	}

	return _hard_linkComment($linkdata) if $constants->{comments_hardcoded};
	slashDisplay('linkComment', $linkdata, { Return => 1, Nocomm => 1 });
}

#========================================================================

=head2 createMenu(MENU)

Creates a menu.

=over 4

=item Parameters

=over 4

=item MENU

The name of the menu to get.

=back

=item Return value

The menu.

=item Dependencies

The template blocks 'admin', 'user' (in the 'menu' page), and any other
template blocks for menus, along with all the data in the
'menus' table.

=back

=cut

sub createMenu {
	my($menu, $options) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();

	return if $menu eq 'users' && $constants->{users_menu_no_display};

	# The style of menu desired.  While we're "evolving" the way we do
	# menus, createMenu() handles several different styles.
	my $style = $options->{style} || "";
	$style = 'oldstyle' unless $style eq 'tabbed';

	# Use the colored background, for tabs that sit on top of the
	# colored titlebar, or use the white background, for tabs that sit
	# on top of the page below ("within" the colored titlebar)?
	my $color = $options->{color} || "";
	$color = 'colored' unless $color eq 'white';

	# Get the list of menu items from the "menus" table.  Then add in
	# any special ones passed in.
	my $menu_items = getCurrentMenu($menu);
	if ($options->{extra_items} && @{$options->{extra_items}}) {
		push @$menu_items, @{$options->{extra_items}};
	}
	if ($menu eq 'users'
		&& $user->{lastlookuid}
		&& $user->{lastlookuid} =~ /^\d+$/
		&& $user->{lastlookuid} != $user->{uid}
		&& ($user->{lastlooktime} || 0) >= time - ($constants->{lastlookmemory} || 3600)
	) {
		my $ll_nick = $reader->getUser($user->{lastlookuid}, 'nickname');
		my $nick_fix = fixparam($ll_nick);
		my $nick_attribute = strip_attribute($ll_nick);
		push @$menu_items, {
			value =>	"$gSkin->{real_rootdir}/~$nick_fix",
			label =>	"~$nick_attribute ($user->{lastlookuid})",
			sel_label =>	"otheruser",
			menuorder =>	99999,
		};
	}

	if (!$menu_items || !@$menu_items) {
		return "";
#		return "<!-- createMenu($menu, $style, $color), no items -->\n"; # DEBUG
	}

	# Now convert each item in the list into a hashref that can
	# be passed to the appropriate template.  The different
	# styles of templates each take a slightly different format
	# of data, and createMenu() is the front-end that makes sure
	# they get what they expect.
	my $items = [];
	for my $item (sort { $a->{menuorder} <=> $b->{menuorder} } @$menu_items) {

		# Only use items that the user can see.
		next if $item->{seclev} && $user->{seclev} < $item->{seclev};
		next if !$item->{showanon} && $user->{is_anon};

		my $opts = { Return => 1, Nocomm => 1 };
		my $data = { };
		$data->{value} = $item->{value} && slashDisplay(\$item->{value}, 0, $opts);
		$data->{label} = $item->{label} && slashDisplay(\$item->{label}, 0, $opts);
		if ($style eq 'tabbed') {
			# Tabbed menus don't display menu items with no
			# links on them.
			next unless $data->{value};
			# Reconfigure data for what the tabbedmenu
			# template expects.
			$data->{sel_label} = $item->{sel_label} || lc($data->{label});
			$data->{sel_label} =~ s/\s+//g;
			$data->{label} =~ s/ +/&nbsp;/g;
			$data->{link} = $data->{value};
		}

		push @$items, $data;
	}

	my $menu_text = "";
#	$menu_text .= "<!-- createMenu($menu, $style, $color), " . scalar(@$items) . " items -->\n"; # DEBUG

	if ($style eq 'tabbed') {
		# All menus in the tabbed style use the same template.
		$menu_text .= slashDisplay("tabbedmenu",
			{ tabs =>		$items,
			  justify =>		$options->{justify} || 'left',
			  color =>		$color,
			  tab_selected =>	$options->{tab_selected},	},
			{ Return => 1, Page => 'menu' });
	} elsif ($style eq 'oldstyle') {
		# Oldstyle menus each hit a different template,
		# "$menu;menu;default" -- so the $menu input refers
		# not only to the column "menu" in table "menus" but
		# also to which template to look up.  If no template
		# with that name is available (or $menu;misc;default,
		# or $menu;menu;light or whatever the fallbacks are)
		# then punt and go with "users;menu;default".
		my $nm = $reader->getTemplateByName($menu, {
			page            => 'menu',
			ignore_errors   => 1
		});
		$menu = "users" unless $nm->{page} && $nm->{page} eq "menu";
		if (@$items) {
			$menu_text .= slashDisplay($menu,
				{ items =>	$items,
				  color =>	$color,
				  lightfontcolor => $options->{lightfontcolor} || ""
				},
				{ Return => 1, Page => 'menu' });
		}
	}

	return $menu_text;
}

########################################################
# use lockTest to test if a story is being edited by someone else
########################################################
sub getImportantWords {
	my($s) = @_;
	return ( ) if !defined($s) || $s eq '';
	$s =~ s/[^A-Z0-9 ]//gi;
	my @w = split m/ /, $s;
	my @words = ( );
	foreach (@w) {
		if (length($_) > 3 || (length($_) < 4 && uc($_) eq $_)) {
			push @words, $_;
		}
	}
	return @words;
}

########################################################
sub matchingStrings {
	my($s1, $s2) = @_;
	return if !defined($s1) || !defined($s2);
	return '100' if $s1 eq $s2;
	my @w1 = getImportantWords($s1);
	my @w2 = getImportantWords($s2);
	my $m = 0;
	return if @w1 < 2 || @w2 < 2;
	foreach my $w (@w1) {
		foreach (@w2) {
			$m++ if $w eq $_;
		}
	}
	return int($m / @w1 * 100) if $m;
	return;
}

########################################################
sub lockTest {
	my($subj) = @_;
	return unless $subj;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $msg = '';
	my $locks = $slashdb->getSessions([qw|lasttitle uid|]);
	for (values %$locks) {
		next unless $_->{lasttitle};
		if ($_->{uid} ne getCurrentUser('uid') && (my $pct = matchingStrings($_->{lasttitle}, $subj))) {
			$msg .= slashDisplay('lockTest', {
				percent		=> $pct,
				subject		=> $_->{lasttitle},
				nickname	=> $slashdb->getUser($_->{uid}, 'nickname')
			}, 1);
		}
	}
	return $msg;
}

########################################################
# this sucks, but it is here for now
sub _hard_linkComment {
	my($linkdata) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();

	my $subject = $linkdata->{subject};

	my $display = qq|<a |;
	$display .= qq|id="$linkdata->{a_id}" |    if $linkdata->{a_id};
	$display .= qq|class="$linkdata->{a_class}" | if $linkdata->{a_class};
	$display .= qq|href="$gSkin->{rootdir}/comments.pl?sid=$linkdata->{sid}|;
	$display .= "&amp;op=$linkdata->{op}" if defined($linkdata->{op});
	$display .= "&amp;threshold=$linkdata->{threshold}" if defined($linkdata->{threshold});
	$display .= "&amp;commentsort=$user->{commentsort}" if defined $linkdata->{commentsort};
	$display .= "&amp;mode=$user->{mode}" if defined $linkdata->{mode};
	$display .= "&amp;no_d2=1" if $user->{state}{no_d2} || $linkdata->{no_d2};
	$display .= "&amp;startat=$linkdata->{startat}" if $linkdata->{startat};
	$display .= "&amp;tid=$user->{state}{tid}"
		if $constants->{tids_in_urls} && $user->{state}{tid};

	if ($linkdata->{comment}) {
		$display .= "&amp;cid=$linkdata->{cid}";
	} else {
		$display .= "&amp;pid=" . ($linkdata->{original_pid} || $linkdata->{pid});
		$display .= "#$linkdata->{cid}" if $linkdata->{cid};
	}

	$display .= qq|" onclick="$linkdata->{onclick}| if $linkdata->{onclick};
	$display .= qq|">$subject</a>|;
	if (!$linkdata->{subject_only}) {
		$display .= qq| by $linkdata->{nickname}|;
		$display .= qq| (Score:$linkdata->{points})|
			if !$user->{noscores} && $linkdata->{points};
		$display .= " " . timeCalc($linkdata->{'time'}) 
			if $linkdata->{date};
	}
	#$display .= "\n";

	return $display;
}

#========================================================================
my $slashTags = {
	'file'     => \&_slashFile,
	'image'    => \&_slashImage,
	'link'     => \&_slashLink,
	'related'  => \&_slashRelated,
	'user'     => \&_slashUser,
	'story'    => \&_slashStory,
	'break'    => \&_slashPageBreak,
	'comment'  => \&_slashComment,
	'journal'  => \&_slashJournal,
};

my $cleanSlashTags = {
	'link'     => \&_cleanSlashLink,
	'related'  => \&_cleanSlashRelated,
	'user'     => \&_cleanSlashUser,
	'story'    => \&_cleanSlashStory,
	'nickname' => \&_cleanSlashUser, # alternative syntax
	'comment'  => \&_cleanSlashComment,
	'journal'  => \&_cleanSlashJournal,
};

sub cleanSlashTags {
	my($text, $options) = @_;
	return unless $text;

	my $tag_re = join '|', sort keys %$slashTags;
	$text =~ s#<SLASH-($tag_re)#<SLASH TYPE="\L$1\E"#gis;
	my $newtext = $text;
	my $tokens = Slash::Custom::TokeParser->new(\$text);
	while (my $token = $tokens->get_tag('slash')) {
		my $type = lc($token->[1]{type});
		if (ref($cleanSlashTags->{$type}) ne 'CODE') {
			$type = $token->[1]{href}     ? 'link'  :
				$token->[1]{story}    ? 'story' :
				$token->[1]{nickname} ? 'user'  :
				$token->[1]{user}     ? 'user'  :
				undef;
		}
		$cleanSlashTags->{$type}($tokens, $token, \$newtext)
			if $type;
	}

	return $newtext;
}

sub _cleanSlashLink {
	my($tokens, $token, $newtext) = @_;
	my $reloDB = getObject('Slash::Relocate');

	if ($reloDB) {
		my $link  = $reloDB->create({ url => $token->[1]{href} });
		my $href  = strip_attribute($token->[1]{href});
		my $title = strip_attribute($token->[1]{title});
		$$newtext =~ s#\Q$token->[3]\E#<slash href="$href" id="$link" title="$title" type="link">#is;
	}
}

sub _cleanSlashRelated {
	my($tokens, $token, $newtext) = @_;

	my $href  = strip_attribute($token->[1]{href});
	my $text;
	if ($token->[1]{text}) {
		$text = $token->[1]{text};
	} else {
		$text = $tokens->get_text("/slash");
	}

	my $content = qq|<slash href="$href" type="related">$text</slash>|;
	if ($token->[1]{text}) {
		$$newtext =~ s#\Q$token->[3]\E#$content#is;
	} else {
		$$newtext =~ s#\Q$token->[3]$text</SLASH>\E#$content#is;
	}
}

sub _cleanSlashUser {
	my($tokens, $token, $newtext) = @_;

	my $user = $token->[1]{user} || $token->[1]{nickname} || $token->[1]{uid};
	return unless $user;

	my $slashdb = getCurrentDB();
	my($uid, $nickname);
	if ($user =~ /^\d+$/) {
		$uid = $user;
		$nickname = $slashdb->getUser($uid, 'nickname');
	} else {
		$nickname = $user;
		$uid = $slashdb->getUserUID($nickname);
	}

	$uid = strip_attribute($uid);
	$nickname = strip_attribute($nickname);
	my $content = qq|<slash nickname="$nickname" uid="$uid" type="user">|;
	$$newtext =~ s#\Q$token->[3]\E#$content#is;
}

sub _cleanSlashStory {
	my($tokens, $token, $newtext) = @_;
	return unless $token->[1]{story};

	my $text;
	if ($token->[1]{text}) {
		$text = $token->[1]{text};
	} else {
		$text = $tokens->get_text('/slash');
	}

	my $slashdb = getCurrentDB();
	my $title = $token->[1]{title}
		? strip_attribute($token->[1]{title})
		: strip_attribute($slashdb->getStory($token->[1]{story}, 'title', 1));
	my $sid = strip_attribute($token->[1]{story});

	my $content = qq|<slash story="$sid" title="$title" type="story">$text</slash>|;
	if ($token->[1]{text}) {
		$$newtext =~ s#\Q$token->[3]\E#$content#is;
	} else {
		$$newtext =~ s#\Q$token->[3]$text</slash>\E#$content#is;
	}
}

sub _cleanSlashComment {
}
sub _cleanSlashJournal {
}

sub processSlashTags {
	my($text, $options) = @_;
	return unless $text;

	my $newtext = $text;
	my $tokens = Slash::Custom::TokeParser->new(\$text);

	return $newtext unless $tokens;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $close = $constants->{xhtml} ? ' /' : '';

	while (my $token = $tokens->get_tag('slash')) {
		my $type = lc($token->[1]{type});
		if (ref($slashTags->{$type}) eq 'CODE') {
			$slashTags->{$type}($tokens, $token, \$newtext);
		} else {
			my $content = Slash::getData('SLASH-UNKNOWN-TAG', { tag => $token->[0] });
			print STDERR "BAD TAG $token->[0]:$type\n";
			$newtext =~ s/\Q$token->[3]\E/$content/;
		}
	}

	# SLASH-BREAK is only allowed in bodytext, so we pass it in as a
	# hardcoded option to the processSlashTags call -- pudge
	if ($options->{break}) {
		my $form = getCurrentForm();
		if ($user->{state}{pagebreaks}) {
			if ($user->{state}{editing}) {
				$newtext =~ s|<slash type="break">|<hr$close>|gis;
			} else {
				my @parts = split m|<slash type="break">|is, $newtext;
				if ($form->{pagenum}) {
					$newtext = $parts[$form->{pagenum} - 1];
					if ($newtext eq '') { # nonexistent page, reset
						$newtext = $parts[0];
						$form->{pagenum} = 0;
					}
				} else {
					$newtext = $parts[0];
					$form->{pagenum} = 1;
				}
			}
		} else {
			$form->{pagenum} = 0;
		}
	}

	return $newtext;
}

sub _slashFile {
	my($tokens, $token, $newtext) = @_;

	my $id = $token->[1]{id};
	my $title = $token->[1]{title};
	my $text = $tokens->get_text('/slash');
	$title ||= $text;
	my $content = slashDisplay('fileLink', {
		id    => $id,
		title => $title,
		text  => $text,
	}, {
		Return => 1,
		Nocomm => 1,
	});
	$content ||= Slash::getData('SLASH-UNKNOWN-FILE');

	$$newtext =~ s#\Q$token->[3]$text</slash>\E#$content#is;
}

sub _slashImage {
	my($tokens, $token, $newtext) = @_;

	if (!$token->[1]{width} || !$token->[1]{height}) {
		my $blob = getObject('Slash::Blob', { db_type => 'reader' });
		my $data = $blob->get($token->[1]{id});
		if ($data && $data->{data}) {
			my($w, $h) = imgsize(\$data->{data});
			$token->[1]{width}  = $w if $w && !$token->[1]{width};
			$token->[1]{height} = $h if $h && !$token->[1]{height};
		}
	}
	if (!$token->[1]{width} || !$token->[1]{height}) {
		print STDERR scalar(localtime) . " _slashImage width or height unknown for image blob id '$token->[1]{id}', resulting HTML page may be non-optimal\n";
	}

	my $content = slashDisplay('imageLink', {
		id	=> $token->[1]{id},
		title	=> $token->[1]{title},
		align	=> $token->[1]{align},
		width	=> $token->[1]{width},
		height	=> $token->[1]{height},
	}, {
		Return => 1,
		Nocomm => 1,
	});
	$content ||= Slash::getData('SLASH-UNKNOWN-IMAGE');

	$$newtext =~ s/\Q$token->[3]\E/$content/;
}

sub _slashLink {
	my($tokens, $token, $newtext) = @_;

	my $text = $tokens->get_text('/slash');
	my $content = slashDisplay('hrefLink', {
		id		=> $token->[1]{id},
		href		=> $token->[1]{href},
		title		=> $token->[1]{title} || $token->[1]{href} || $text,
		text		=> $text,
	}, {
		Return => 1,
		Nocomm => 1,
	});

	$content ||= Slash::getData('SLASH-UNKNOWN-LINK');

	$$newtext =~ s#\Q$token->[3]$text</slash>\E#$content#is;
}

sub _slashRelated {
	my($tokens, $token, $newtext) = @_;
	my $user = getCurrentUser();

	my $link = $token->[1]{href};
	my $text = $tokens->get_text('/slash');

	push @{$user->{state}{related_links}}, [ $text, $link ];
	$$newtext =~ s#\Q$token->[3]$text</SLASH>\E##is;
}

sub _slashUser {
	my($tokens, $token, $newtext) = @_;

	my $content = slashDisplay('userLink', {
		uid      => $token->[1]{uid},
		nickname => $token->[1]{nickname},
	}, {
		Return => 1,
		Nocomm => 1,
	});
	$content ||= Slash::getData('SLASH-UNKNOWN-USER');

	$$newtext =~ s/\Q$token->[3]\E/$content/;
}

sub _slashStory {
	my($tokens, $token, $newtext) = @_;

	my $sid = $token->[1]{story};
	my $text = $tokens->get_text("/slash");
	my $storylinks = linkStory({
		'link'	=> $text,
		sid	=> $token->[1]{story},
		title	=> $token->[1]{title},
	});

	my $content;
	if ($storylinks->[0] && $storylinks->[2]) {
		$content = '<a href="' . strip_attribute($storylinks->[0]) . '"';
		$content .= ' title="' . strip_attribute($storylinks->[2]) . '"'
			if $storylinks->[2] ne '';
		$content .= '>' . strip_html($storylinks->[1]) . '</a>';
	}

	$content ||= Slash::getData('SLASH-UNKNOWN-STORY');

	$$newtext =~ s#\Q$token->[3]$text</slash>\E#$content#is;
}

sub _slashPageBreak {
	my($tokens, $token, $newtext) = @_;
	my $user = getCurrentUser();

	$user->{state}{pagebreaks}++;
}

sub _slashComment {
	my($tokens, $token, $newtext) = @_;
}

sub _slashJournal {
	my($tokens, $token, $newtext) = @_;
}

# sigh ... we had to change one line of TokeParser rather than
# waste time rewriting the whole thing -- pudge
package Slash::Custom::TokeParser;

use base 'HTML::TokeParser';

sub get_text
{
    my $self = shift;
    my $endat = shift;
    my @text;
    while (my $token = $self->get_token) {
	my $type = $token->[0];
	if ($type eq "T") {
	    my $text = $token->[1];
# this is the one changed line
#	    decode_entities($text) unless $token->[2];
	    push(@text, $text);
	} elsif ($type =~ /^[SE]$/) {
	    my $tag = $token->[1];
	    if ($type eq "S") {
		if (exists $self->{textify}{$tag}) {
		    my $alt = $self->{textify}{$tag};
		    my $text;
		    if (ref($alt)) {
			$text = &$alt(@$token);
		    } else {
			$text = $token->[2]{$alt || "alt"};
			$text = "[\U$tag]" unless defined $text;
		    }
		    push(@text, $text);
		    next;
		}
	    } else {
		$tag = "/$tag";
	    }
	    if (!defined($endat) || $endat eq $tag) {
		 $self->unget_token($token);
		 last;
	    }
	}
    }
    join("", @text);
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).
