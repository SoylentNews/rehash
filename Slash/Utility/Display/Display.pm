# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

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
# use Date::Manip qw(ParseDate UnixDate);
use Slash::Display;
use Slash::Utility::Data;
use Slash::Utility::Environment;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(
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
	selectMode
	selectSection
	selectSortcode
	selectThreshold
	selectTopic
	titlebar
);

#========================================================================

=head2 createSelect(LABEL, DATA [, DEFAULT, RETURN, NSORT, ORDERED])

Creates a drop-down list in HTML.  List is sorted by default
alphabetically according to list values.

=over 4

=item Parameters

=over 4

=item LABEL

The name for the HTML entity.

=item DATA

A hashref containing key-value pairs for the list.
Keys are list values, and values are list labels.
If an arrayref is passed, it is converted to a
hashref, where the keys and values are the same.

=item DEFAULT

Default value for the list.

=item RETURN

See "Return value" below.

=item NSORT

Sort numerically, not alphabetically.

=item ORDERED

If an arrayref is passed, an already-sorted array reference of keys.
If non-ref, then an arrayref of hash keys is created sorting the
hash values, alphabetically and case-insensitively.
If ORDERED is passed in either form, then the NSORT parameter is ignored.

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
	my($label, $hashref, $default, $return, $nsort, $ordered) = @_;

	if (ref $hashref eq 'ARRAY') {
		$hashref = { map { ($_, $_) } @$hashref };
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
		label	=> $label,
		items	=> $hashref,
		default	=> $default,
		numeric	=> $nsort,
		ordered	=> $ordered,
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
	my($label, $default, $section, $return, $all) = @_;
	my $slashdb = getCurrentDB();
	$section ||= getCurrentStatic('defaultsection');
	$default ||= getCurrentStatic('defaulttopic');

	my $topics = $slashdb->getDescriptions('topics_section', $section);

	my $ordered = [
		map  { $_->[0] }
		sort { $a->[1] cmp $b->[1] }
		map  { [$_, lc $topics->{$_}] }
		keys %$topics
	];

	createSelect($label, $topics, $default, $return, 0, $ordered);
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

Hashref for current section.  If SECT->{isolate} is true,
list is not created, but hidden value is returned instead.

=item RETURN

See "Return value" below.

=item ALL

Boolean for including "All Topics" item.

=back

=item Return value

If RETURN is true, the text of the list is returned.
Otherwise, list is just printed, and returns
true/false if operation is successful.

=item Dependencies

The 'sectionisolate' template block.

=back

=cut

sub selectSection {
	my($label, $default, $SECT, $return, $all) = @_;
	my $slashdb = getCurrentDB();

	$SECT ||= {};
	if ($SECT->{isolate}) {
		slashDisplay('sectionisolate',
			{ name => $label, section => $default });
		return;
	}

	my $seclev = getCurrentUser('seclev');
	my $sectionbank = $slashdb->getSections();
	my %sections = map {
		($_, $sectionbank->{$_}{title})
	} grep {
		!($sectionbank->{$_}{isolate} && $seclev < 500)
	} keys %$sectionbank;

	createSelect($label, \%sections, $default, $return);
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
	my $slashdb = getCurrentDB();
	createSelect('commentsort', $slashdb->getDescriptions('sortcodes'),
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
	my $slashdb = getCurrentDB();

	createSelect('mode', $slashdb->getDescriptions('commentmodes'),
		getCurrentUser('mode'), 1);
}

#========================================================================

=head2 selectThreshold(COUNTS)

Creates a drop-down list of thresholds in HTML.  Default is the user's
preference.  Calls C<createSelect>.

=over 4

=item Parameters

=over 4

=item COUNTS

An arrayref of thresholds -E<gt> counts for that threshold.

=back

=item Return value

The created list.

=item Dependencies

The 'selectThreshLabel' template block.

=back

=cut

sub selectThreshold  {
	my($counts) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my %data;
	foreach my $c ($constants->{comment_minscore} .. $constants->{comment_maxscore}) {
		$data{$c} = slashDisplay('selectThreshLabel', {
			points	=> $c,
			count	=> $counts->[$c - $constants->{comment_minscore}],
		}, { Return => 1, Nocomm => 1 });
	}

	createSelect('threshold', \%data, getCurrentUser('threshold'), 1, 1);
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
	my($story_link) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my $mode = $story_link->{mode} || $user->{mode};
	my $threshold = undef;
	$threshold = $story_link->{threshold} if exists $story_link->{threshold};
	my $dynamic = 0;

	# Setting $dynamic properly is important.  When generating the
	# AC index.shtml, it's a big win if we link to other
	# prerendered .shtml URLs whenever possible/appropriate.
	# But, we must link to the .pl when necessary.

	if ($ENV{SCRIPT_NAME} or !$user->{is_anon}) {
		# Whenever we're invoked from Apache, use dynamic links.
		# This test will be true 99% of the time we come through
		# here, so it's first.
		$dynamic = 1;
	} elsif ($mode) {
		# If we're an AC script, but this is a link to e.g.
		# mode=nocomment, then we need to have it be dynamic.
		$dynamic = 1 if $mode ne $slashdb->getUser(
			$constants->{anonymous_coward_uid},
			'mode',
		);
	}
	if (!$dynamic and defined($threshold)) {
		# If we still think we can get away with a nondynamic link,
		# we need to check one more thing.  Even an AC linking to
		# an article needs to make the link dynamic if it's the
		# "n comments" link, where threshold = -1.  For maximum
		# compatibility we check against the AC's threshold.
		$dynamic = 1 if $threshold != $slashdb->getUser(
			$constants->{anonymous_coward_uid},
			'threshold'
		);
	}

	return _hard_linkStory($story_link, $mode, $threshold, $dynamic)
		if $constants->{comments_hardcoded} && !$user->{light};

	return slashDisplay('linkStory', {
		mode		=> $mode,
		threshold	=> $threshold,
		tid		=> $story_link->{tid},
		sid		=> $story_link->{sid},
		section		=> $story_link->{section},
		url		=> $slashdb->getSection($story_link->{section}, 'url'),
		text		=> $story_link->{'link'},
		dynamic		=> $dynamic,
	}, { Return => 1, Nocomm => 1 });
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

sub pollbooth {
	my($qid, $no_table, $center) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $sect = getCurrentUser('currentSection');

	# This special qid means to use the current (sitewide) poll.
	$qid = $slashdb->getVar('currentqid', 'value') if $qid eq '_currentqid';
	# If no qid (or no sitewide poll), short-circuit out.
	return "" if $qid eq "";

	my $poll = $slashdb->getPoll($qid);
	return "" unless %$poll;
	my $n_comments = $slashdb->countCommentsBySid(
		$poll->{pollq}{discussion});
	my $poll_open = $slashdb->isPollOpen($qid);
	my $has_voted = $slashdb->hasVotedIn($qid);
	my $can_vote = !$has_voted && $poll_open;

	my $pollbooth = slashDisplay('pollbooth', {
		question	=> $poll->{pollq}{question},
		answers		=> $poll->{answers},
		qid		=> $qid,
		poll_open	=> $poll_open,
		has_voted	=> $has_voted,
		can_vote	=> $can_vote,
		voters		=> $poll->{pollq}{voters},
		comments	=> $n_comments,
		sect		=> $sect,
	}, 1);

	return $no_table
		? $pollbooth
		: fancybox(
			$constants->{fancyboxwidth}, 'Poll',
			$pollbooth, $center, 1
		);
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
	my $html_to_display;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

# 	my $now = UnixDate(ParseDate($slashdb->getTime()), "%s");
	my $now = timeCalc($slashdb->getTime(), "%s", 0);
	my $aids = $slashdb->currentAdmin();
	for my $data (@$aids) {
		my($usernick, $usertime, $lasttitle, $uid) = @$data;
		if ($usernick eq $user->{nickname}) {
			$usertime = "-";
		} else {
			$usertime = $now - timeCalc($usertime, "%s", 0); # UnixDate(ParseDate($usertime), "%s");
			if ($usertime <= 99) {
				$usertime .= "s";
			} elsif ($usertime <= 3600) {
				$usertime = int($usertime/60+0.5) . "m";
			} else {
				$usertime = int($usertime/3600) . "h"
					. int(($usertime%3600)/60+0.5) . "m";
			}
		}
		@$data = ($usernick, $usertime, $lasttitle, $uid);
	}

	return slashDisplay('currentAdminUsers', {
		ids		=> $aids,
		can_edit_admins	=> $user->{seclev} > 10000,
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
	$horizmenu =~ s/<HR(?:>|\s[^>]*>)//g;
	$horizmenu = join ' | ', split /<BR>/, $horizmenu;
	$horizmenu =~ s/[\|\s]+$//;
	$horizmenu =~ s/^[\|\s]+//;
	return "[ $horizmenu ]";
}

#========================================================================

=head2 titlebar(WIDTH, TITLE)

Prints a titlebar widget.  Deprecated; exactly equivalent to:

	slashDisplay('titlebar', {
		width	=> $width,
		title	=> $title
	});

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
	my($width, $title) = @_;
	slashDisplay('titlebar', {
		width	=> $width,
		title	=> $title
	});
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

=back

=item Return value

The fancybox if RETURN is true, or true/false
on success/failure.

=item Dependencies

The 'fancybox' template block.

=back

=cut

sub fancybox {
	my($width, $title, $contents, $center, $return) = @_;
	return unless $title && $contents;

	my $tmpwidth = $width;
	# allow width in percent or raw pixels
	my $pct = 1 if $tmpwidth =~ s/%$//;
	# used in some blocks
	my $mainwidth = $tmpwidth-4;
	my $insidewidth = $mainwidth-8;
	if ($pct) {
		for ($mainwidth, $insidewidth) {
			$_ .= '%';
		}
	}

	slashDisplay('fancybox', {
		width		=> $width,
		contents	=> $contents,
		title		=> $title,
		center		=> $center,
		mainwidth	=> $mainwidth,
		insidewidth	=> $insidewidth,
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
	my($width, $title, $contents, $bid, $url) = @_;
	return unless $title && $contents;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	$title = slashDisplay('portalboxtitle', {
		title	=> $title,
		url	=> $url,
	}, { Return => 1, Nocomm => 1 });

	if ($user->{exboxes}) {
		$title = slashDisplay('portalmap', {
			title	=> $title,
			bid	=> $bid,
		}, { Return => 1, Nocomm => 1 });
	}

	fancybox($width, $title, $contents, 0, 1);
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
	my($comment, $printcomment, $date) = @_;
	my $constants = getCurrentStatic();
	return _hard_linkComment(@_) if $constants->{comments_hardcoded};

	my $user = getCurrentUser();
	my $adminflag = $user->{seclev} >= 10000 ? 1 : 0;

	# don't inherit these ...
	for (qw(sid cid pid date subject comment uid points lastmod
		reason nickname fakeemail homepage sig)) {
		$comment->{$_} = '' unless exists $comment->{$_};
	}

	slashDisplay('linkComment', {
		%$comment, # defaults
		adminflag	=> $adminflag,
		date		=> $date,
		pid		=> $comment->{realpid} || $comment->{pid},
			# $comment->{threshold}? Hmm. I'm not sure what it
			# means for a comment to have a threshold. If it's 0,
			# does the following line do the right thing? - Jamie
		threshold	=> $comment->{threshold} || $user->{threshold},
		commentsort	=> $user->{commentsort},
		mode		=> $user->{mode},
		comment		=> $printcomment,
	}, { Return => 1, Nocomm => 1 });
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
	my($menu) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $menu_items = getCurrentMenu($menu) or return;
	my $items = [];

	for my $item (sort { $a->{menuorder} <=> $b->{menuorder} } @$menu_items) {
		next unless $user->{seclev} >= $item->{seclev};

		my $opts = { Return => 1, Nocomm => 1 };
		my $value = $item->{value} && slashDisplay(\$item->{value}, 0, $opts);
		my $label = $item->{label} && slashDisplay(\$item->{label}, 0, $opts);

		push @$items, {
			value => $value,
			label => $label,
		};
	}

	# default to "users" menu template
	my $nm = $slashdb->getTemplateByName($menu, 0, 0, "menu");
	$menu = "users" unless $nm->{page} eq "menu";

	if (@$items) {
		return slashDisplay($menu, {
			items	=> $items
		}, {
			Return	=> 1,
			Page	=> 'menu'
		});
	} else {
		return;
	}
}

########################################################
# use lockTest to test if a story is being edited by someone else
########################################################
sub getImportantWords {
	my $s = shift;
	$s =~ s/[^A-Z0-9 ]//gi;
	my @w = split m/ /, $s;
	my @words;
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

	my $msg;
	my $locks = $slashdb->getSessions([qw|lasttitle uid|]);
	for (values %$locks) {
		if ($_->{uid} ne getCurrentUser('uid') && (my $pct = matchingStrings($_->{subject}, $subj))) {
			$msg .= slashDisplay('lockTest', {
				percent		=> $pct,
				subject		=> $_->{subject},
				nickname	=> $slashdb->getUser($_->{uid}, 'nickname')
			}, 1);
		}
	}
	return $msg;
}

########################################################
# this sucks, but it is here for now
sub _hard_linkStory {
	my($story_link, $mode, $threshold, $dynamic) = @_;
	my $constants = getCurrentStatic();

	if ($dynamic) {
	    my $link = qq[<A HREF="$constants->{rootdir}/article.pl?sid=$story_link->{sid}];
	    $link .= "&amp;mode=$mode" if $mode;
	    $link .= "&amp;tid=$story_link->{tid}" if $story_link->{tid};
	    $link .= "&amp;threshold=$threshold" if defined($threshold);
	    $link .= qq[">$story_link->{link}</A>];
	    return $link;
	} else {
	    # this looks wrong ... tid=$tid won't have much effect on .shtml -- pudge
	    return qq[<A HREF="$constants->{rootdir}/$story_link->{section}/$story_link->{sid}.shtml?tid=$story_link->{tid}">$story_link->{link}</A>];
	}
}


########################################################
# this sucks, but it is here for now
sub _hard_linkComment {
	my($comment, $printcomment, $date) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $subject = $comment->{color}
		? qq|<FONT COLOR="$comment->{color}">$comment->{subject}</FONT>|
		: $comment->{subject};

	my $display = qq|<A HREF="$constants->{rootdir}/comments.pl?sid=$comment->{sid}|;
	$display .= "&amp;op=$comment->{op}" if $comment->{op};
		# $comment->{threshold}? Hmm. I'm not sure what it
		# means for a comment to have a threshold. If it's 0,
		# does the following line do the right thing? - Jamie
		# You know, I think this is a bug that comes up every so often. But in 
		# theory when you go to the comment link "threshhold" should follow 
		# with you. -Brian
	$display .= "&amp;threshold=" . ($comment->{threshold} || $user->{threshold});
	$display .= "&amp;commentsort=$user->{commentsort}";
	$display .= "&amp;tid=$user->{state}{tid}" if $user->{state}{tid};
	$display .= "&amp;mode=$user->{mode}";
	$display .= "&amp;startat=$comment->{startat}" if $comment->{startat};

	if ($printcomment) {
		$display .= "&amp;cid=$comment->{cid}";
	} else {
		$display .= "&amp;pid=" . ($comment->{realpid} || $comment->{pid});
		$display .= "#$comment->{cid}" if $comment->{cid};
	}

	$display .= qq!">$subject</A>!;
	$display .= qq| by $comment->{nickname} <FONT SIZE="-1">(Score:$comment->{points})</FONT> |
		if !$user->{noscores} && $comment->{points};
	$display .= qq| <FONT SIZE="-1">| . timeCalc($comment->{date}) . qq| </FONT>| if $date;
	$display .= "\n";

	return $display;
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$
