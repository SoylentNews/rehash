# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash;

# BENDER: It's time to kick some shiny metal ass!

=head1 NAME

Slash - the BEAST

=head1 SYNOPSIS

	use Slash;  # figure the rest out ;-)

=head1 DESCRIPTION

Slash is the code that runs Slashdot.

=head1 FUNCTIONS

Unless otherwise noted, they are publically available functions.

=cut

use strict;  # ha ha ha ha ha!
use Apache;
use Apache::SIG ();
use DBI;
use Data::Dumper;  # the debuggerer's best friend
use Exporter ();
use File::Spec::Functions;
use Symbol 'gensym';
use HTML::Entities;
use URI;
use Date::Manip qw( ParseDate UnixDate );

use Slash::DB;
use Slash::Display;
use Slash::Utility;

use vars qw($VERSION @ISA @EXPORT);

# this is the worst damned warning ever, so SHUT UP ALREADY!
$SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /Use of uninitialized value/ };

$VERSION = '2.000000';	# v2.0.0
@ISA	 = 'Exporter';
@EXPORT  = qw(
	checkSubmission createMenu createSelect
	currentAdminUsers dispComment displayStory displayThread
	dispStory errorMessage fancybox footer getData getFormkeyId
	getOlderStories getSection getSectionBlock getsiddir
	header horizmenu linkComment linkStory lockTest
	moderatorCommentLog pollbooth portalbox printComments
	redirect selectMode selectSection selectSortcode
	selectThreshold selectTopic titlebar gensym
);  # anonLog

# BENDER: Fry, of all the friends I've had ... you're the first.

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

An already-sorted array reference of keys.  If passed, then
the NSORT parameter is ignored.

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

=head2 selectTopic(LABEL [, DEFAULT, RETURN, ALL])

Creates a drop-down list of topics in HTML.  Calls C<createSelect>.

=over 4

=item Parameters

=over 4

=item LABEL

The name for the HTML entity.

=item DEFAULT

Default topic for the list.

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

sub selectTopic {
	my($label, $default, $return, $all) = @_;
	my $slashdb = getCurrentDB();

	my $topicbank = $slashdb->getTopics();
	my %topics = map {
		($_, $topicbank->{$_}{alttext})
	} keys %$topicbank;
	delete $topics{''} unless $all;

	createSelect($label, \%topics, $default, $return);
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
	delete $sections{''} unless $all;

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

########################################################
# Gets the appropriate block depending on your section
# or else fall back to one that exists
sub getSectionBlock {
	my($name) = @_;
	my $slashdb = getCurrentDB();
	my $thissect = getCurrentUser('light') ? 'light' : getCurrentUser('currentSection');
	my $block;

	if ($thissect) {
		$block = $slashdb->getBlock("${thissect}_${name}", 'block');
	}

	$block ||= $slashdb->getBlock($name, 'block');
	return $block;
}

###############################################################	
#  What is it?  Where does it go?  The Random Leftover Shit

########################################################
# Returns the directory (eg YY/MM/DD/) that stories are being written in today
sub getsiddir {
	my($mday, $mon, $year) = (localtime)[3, 4, 5];
	$year = $year % 100;
	my $sid = sprintf('%02d/%02d/%02d/', $year, $mon+1, $mday);
	return $sid;
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
	my($mode, $threshold);

	if ($ENV{SCRIPT_NAME} || !$story_link->{section}) {
		$mode = $story_link->{mode} || $user->{mode};
		$threshold = $story_link->{threshold} if exists $story_link->{threshold};
	}

	return slashDisplay('linkStory', {
		mode		=> $mode,
		threshold	=> $threshold,
		sid		=> $story_link->{sid},
		section		=> $story_link->{section},
		text		=> $story_link->{'link'}
	}, { Return => 1, Nocomm => 1 });
}

########################################################
# Sets the appropriate @fg and @bg color pallete's based
# on what section you're in.  Used during initialization
sub getSectionColors {
	my($color_block) = @_;
	my $user = getCurrentUser();
	my @colors;
	my $colorblock = getCurrentForm('colorblock');

	# they damn well better be legit
	if ($colorblock) {
		@colors = map { s/[^\w#]+//g ; $_ } split m/,/, $colorblock;
	} else {
		@colors = split m/,/, getSectionBlock('colors');
	}

	$user->{fg} = [@colors[0..4]];
	$user->{bg} = [@colors[5..9]];
}


########################################################
# Gets sections wherver needed.  if blank, gets settings for homepage, and
# if defined tries to use cache.
# Look at this for a rewrite
sub getSection {
	my($section) = @_;
	return { title => getCurrentStatic('sitename').": ".getCurrentStatic('slogan'),
		artcount => getCurrentUser('maxstories') || 30, issue => 3 }
		unless $section;
	my $slashdb = getCurrentDB();
	return $slashdb->getSection($section);
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

	$qid = $slashdb->getVar('currentqid', 'value') unless $qid;
	return "" if $qid eq "";
	my $sect = getCurrentUser('currentSection');
	my $polls = $slashdb->getPoll($qid);

	my $pollbooth = slashDisplay('pollbooth', {
		polls		=> $polls,
		question	=> $polls->[0][0],
		qid		=> $qid,
		voters		=> $slashdb->getPollQuestion($qid, 'voters'),
		comments	=> $slashdb->countCommentsBySid($qid),
		sect		=> $sect,
	}, 1);

	return $pollbooth if $no_table;
	fancybox($constants->{fancyboxwidth}, 'Poll', $pollbooth, $center, 1);
}

########################################################
# Look and Feel Functions Follow this Point
########################################################

#========================================================================

=head2 ssiHead()

Prints the head for server-parsed HTML pages.

=over 4

=item Return value

The SSI head.

=item Dependencies

The 'ssihead' template block.

=back

=cut

sub ssiHead {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	(my $dir = $constants->{rootdir}) =~ s|^(?:https?:)?//[^/]+||;

	slashDisplay('ssihead', {
		dir	=> $dir,
		section => "$user->{currentSection}/"
	});
}

#========================================================================

=head2 ssiFoot()

Prints the foot for server-parsed HTML pages.

=over 4

=item Return value

The SSI foot.

=item Dependencies

The 'ssifoot' template block.

=back

=cut

sub ssiFoot {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	(my $dir = $constants->{rootdir}) =~ s|^(?:https?:)?//[^/]+||;

	slashDisplay('ssifoot', {
		dir	=> $dir,
		section => "$user->{currentSection}/"
	});
}

#========================================================================

=head2 formLabel(VALUE [, COMMENT])

Prints a label for a form element.

=over 4

=item Parameters

=over 4

=item VALUE

The label.

=item COMMENT

An additional comment to stick in parentheses.

=back

=item Return value

The form label.

=item Dependencies

The 'formLabel' template block.

=back

=cut

sub formLabel {
	my($value, $comment) = @_;
	return unless $value;

	my %data;
	$data{value} = $value;
	$data{comment} = $comment if defined $_[1];

	slashDisplay('formLabel', \%data, { Return => 1, Nocomm => 1 });
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

	my $now = UnixDate(ParseDate($slashdb->getTime()), "%s");
	my $aids = $slashdb->currentAdmin();
	for my $data (@$aids) {
		my($usernick, $usertime, $lasttitle) = @$data;
		if ($usernick eq $user->{nickname}) {
			$usertime = "-";
		} else {
			$usertime = $now - UnixDate(ParseDate($usertime), "%s");
			if ($usertime <= 99) {
				$usertime .= "s";
			} elsif ($usertime <= 3600) {
				$usertime = int($usertime/60+0.5) . "m";
			} else {
				$usertime = int($usertime/3600) . "h"
					. int(($usertime%3600)/60+0.5) . "m";
			}
		}
		@$data = ($usernick, $usertime, $lasttitle);
	}

	return slashDisplay('currentAdminUsers', {
		ids		=> $aids,
		can_edit_admins	=> $user->{seclev} > 10000,
	}, 1);
}

########################################################
sub getAd {
	my $num = $_[0] || 1;
	return qq|<!--#perl sub="sub { use Slash; print Slash::getAd($num); }" -->|
		unless $ENV{SCRIPT_NAME};

	return $ENV{"AD_BANNER_$num"};
}

#========================================================================

=head2 redirect(URL)

Redirect browser to URL.

=over 4

=item Parameters

=over 4

=item URL

URL to redirect browser to.

=back

=item Return value

None.

=item Dependencies

The 'html-redirect' template block.

=back

=cut

sub redirect {
	my($url) = @_;
	$url = url2abs($url);
	my $r = Apache->request;

	$r->content_type('text/html');
	$r->header_out(Location => $url);
	$r->status(302);
	$r->send_http_header;

	slashDisplay('html-redirect', { url => $url });
}

#========================================================================

=head2 header([TITLE, SECTION, STATUS])

Prints the header for the document.

=over 4

=item Parameters

=over 4

=item TITLE

The title for the HTML document.  The HTML header won't
print without this.

=item SECTION

The section to handle the header.  This sets the
currentSection constant, too.

=item STATUS

A special status to print in the HTTP header.

=back

=item Return value

None.

=item Side effects

Sets currentSection constant.

=item Dependencies

The 'html-header' and 'header' template blocks.

=back

=cut

sub header {
	my($title, $section, $status) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $adhtml = '';
	$title ||= '';

	unless ($form->{ssi}) {
		my $r = Apache->request;
# This is here as a reminder -Brian
#		$params{-status} = $status if $status;

# we need to doublecheck that Pragma header is not required -- pudge

		unless ($user->{seclev} || $ENV{SCRIPT_NAME} =~ /comments/) {
			$r->header_out('Cache-Control', 'no-cache')
		} else {
			$r->header_out('Cache-Control', 'private')
		}

		$r->content_type('text/html');
		$r->send_http_header;
	}

	$user->{currentSection} = $section || '';
	getSectionColors();

	$title =~ s/<(.*?)>//g;

	slashDisplay('html-header', { title => $title }, { Nocomm => 1 }) if $title;

	# ssi = 1 IS NOT THE SAME as ssi = 'yes'
	if ($form->{ssi} eq 'yes') {
		ssiHead($section);
		return;
	}

	if ($constants->{run_ads}) {
		$adhtml = getAd(1);
	}

	slashDisplay('header');

	print createMenu('admin') if $user->{is_admin};
}

#========================================================================

=head2 footer()

Prints the footer for the document.

=over 4

=item Return value

None.

=item Dependencies

The 'footer' template block.

=back

=cut

sub footer {
	my $form = getCurrentForm();

	if ($form->{ssi}) {
		ssiFoot();
		return;
	}

	slashDisplay('footer', {}, { Nocomm => 1 });
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

########################################################
# Behold, the beast that is threaded comments
sub selectComments {
	my($sid, $cid) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $comments; # One bigass struct full of comments
	foreach my $x (0..6) { $comments->[0]{totals}[$x] = 0 }

	my $thisComment = $slashdb->getCommentsForUser($sid, $cid);
	for my $C (@$thisComment) {
		$C->{pid} = 0 if $user->{commentsort} > 3; # Ignore Threads

		$C->{points}++ if length($C->{comment}) > $user->{clbig}
			&& $C->{points} < $constants->{comment_maxscore} && $user->{clbig} != 0;

		$C->{points}-- if length($C->{comment}) < $user->{clsmall}
			&& $C->{points} > $constants->{comment_minscore} && $user->{clsmall};

		# fix points in case they are out of bounds
		$C->{points} = $constants->{comment_minscore}
			if $C->{points} < $constants->{comment_minscore};
		$C->{points} = $constants->{comment_maxscore}
			if $C->{points} > $constants->{comment_maxscore};

		my $tmpkids = $comments->[$C->{cid}]{kids};
		my $tmpvkids = $comments->[$C->{cid}]{visiblekids};
		$comments->[$C->{cid}] = $C;
		$comments->[$C->{cid}]{kids} = $tmpkids;
		$comments->[$C->{cid}]{visiblekids} = $tmpvkids;

		push @{$comments->[$C->{pid}]{kids}}, $C->{cid};
		$comments->[0]{totals}[$C->{points} - $constants->{comment_minscore}]++;  # invert minscore
		$comments->[$C->{pid}]{visiblekids}++
			if $C->{points} >= ($user->{threshold} || $constants->{comment_minscore});

		$user->{points} = 0 if $C->{uid} == $user->{uid}; # Mod/Post Rule
	}

	my $count = @$thisComment;

	getCommentTotals($comments);
	
	$slashdb->updateCommentTotals($sid, $comments) if $form->{ssi};

	my $hp = join ',', @{$comments->[0]{totals}};

	$slashdb->setStory($sid, {
			hitparade	=> $hp,
			writestatus	=> 0,
			commentcount	=> $comments->[0]{totals}[0]
		}
	);

	reparentComments($comments);
	return($comments, $count);
}

########################################################
sub getCommentTotals {
	my($comments) = @_;
	for my $x (0..5) {
		$comments->[0]{totals}[5-$x] += $comments->[0]{totals}[5-$x+1];
	}
}


########################################################
sub reparentComments {
	my($comments) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $depth = $constants->{max_depth} || 7;

	return unless $depth || $user->{reparent};

	# adjust depth for root pid or cid
	if (my $cid = $form->{cid} || $form->{pid}) {
		while ($cid && (my($pid) = $slashdb->getCommentPid($form->{sid}, $cid))) {
			$depth++;
			$cid = $pid;
		}
	}

	for (my $x = 1; $x < @$comments; $x++) {
		next unless $comments->[$x];

		my $pid = $comments->[$x]{pid};
		my $reparent;

		# do threshold reparenting thing
		if ($user->{reparent} && $comments->[$x]{points} >= $user->{threshold}) {
			my $tmppid = $pid;
			while ($tmppid && $comments->[$tmppid]{points} < $user->{threshold}) {
				$tmppid = $comments->[$tmppid]{pid};
				$reparent = 1;
			}

			if ($reparent && $tmppid >= ($form->{cid} || $form->{pid})) {
				$pid = $tmppid;
			} else {
				$reparent = 0;
			}
		}

		if ($depth && !$reparent) { # don't reparent again!
			# set depth of this comment based on parent's depth
			$comments->[$x]{depth} = ($pid ? $comments->[$pid]{depth} : 0) + 1;

			# go back each pid until we find one with depth less than $depth
			while ($pid && $comments->[$pid]{depth} >= $depth) {
				$pid = $comments->[$pid]{pid};
				$reparent = 1;
			}
		}

		if ($reparent) {
			# remove child from old parent
			if ($pid >= ($form->{cid} || $form->{pid})) {
				@{$comments->[$comments->[$x]{pid}]{kids}} =
					grep { $_ != $x }
					@{$comments->[$comments->[$x]{pid}]{kids}}
			}

			# add child to new parent
			$comments->[$x]{realpid} = $comments->[$x]{pid};
			$comments->[$x]{pid} = $pid;
			push @{$comments->[$pid]{kids}}, $x;
		}
	}
}

#========================================================================

=head2 printComments(SID [, PID, CID])

Prints all that comment stuff.

=over 4

=item Parameters

=over 4

=item SID

The story ID to print comments for.

=item PID

The parent ID of the comments to print.

=item CID

The comment ID to print.

=back

=item Return value

None.

=item Dependencies

The 'printCommentsMain', 'printCommNoArchive',
and 'printCommComments' template blocks.

=back

=cut

sub printComments {
	my($sid, $pid, $cid) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$pid ||= 0;
	$cid ||= 0;
	my $lvl = 0;

	# Get the Comments
	my($comments, $count) = selectComments($sid, $cid || $pid);

	# Should I index or just display normally?
	my $cc = 0;
	if ($comments->[$cid || $pid]{visiblekids}) {
		$cc = $comments->[$cid || $pid]{visiblekids};
	}

	$lvl++ if $user->{mode} ne 'flat' && $user->{mode} ne 'archive'
		&& $cc > $user->{commentspill}
		&& ($user->{commentlimit} > $cc || $user->{commentlimit} > $user->{commentspill});

	if ($user->{mode} ne 'archive') {
		my($title, $section);
		my $slashdb = getCurrentDB();

		if ($slashdb->getStory($sid)) {
			$title = $slashdb->getStory($sid, 'title');
			$section = $slashdb->getStory($sid, 'section');
		} else {
			my $story = $slashdb->getNewStory($sid, ['title', 'section']);
			$title = $story->{title};
			$section = $story->{section};
		}

		slashDisplay('printCommentsMain', {
			comments	=> $comments,
			title		=> $title,
			count		=> $count,
			sid		=> $sid,
			cid		=> $cid,
			pid		=> $pid,
			section		=> $section,
			lvl		=> $lvl,
		});

		return if $user->{mode} eq 'nocomment';

	} else {
		slashDisplay('printCommNoArchive');
	}


	my($comment, $next, $previous);
	if ($cid) {
		my($next, $previous);
		$comment = $comments->[$cid];
		if (my $sibs = $comments->[$comment->{pid}]{kids}) {
			for (my $x = 0; $x < @$sibs; $x++) {
				($next, $previous) = ($sibs->[$x+1], $sibs->[$x-1])
					if $sibs->[$x] == $cid;
			}
		}
		$next = $comments->[$next] if $next;
		$previous = $comments->[$previous] if $previous;
	}

	slashDisplay('printCommComments', {
		can_moderate	=> (($user->{seclev} > 100 || $user->{points}) && !$user->{is_anon}),
		comment		=> $comment,
		comments	=> $comments,
		'next'		=> $next,
		previous	=> $previous,
		sid		=> $sid,
		cid		=> $cid,
		pid		=> $pid,
		cc		=> $cc,
		lcp		=> linkCommentPages($sid, $pid, $cid, $cc),
		lvl		=> $lvl,
	});
}

#========================================================================

=head2 moderatorCommentLog(SID, CID)

Prints a table detailing the history of moderation of
a particular comment.

=over 4

=item Parameters

=over 4

=item SID

Comment's story ID.

=item CID

Comment's ID.

=back

=item Return value

The HTML.

=item Dependencies

The 'modCommentLog' template block.

=back

=cut

sub moderatorCommentLog {
	my($sid, $cid) = @_;
	my $slashdb = getCurrentDB();

	my $seclev = getCurrentUser('seclev');
	my $comments = $slashdb->getModeratorCommentLog($sid, $cid);
	my(@reasonHist, $reasonTotal);

	for my $comment (@$comments) {
		$reasonHist[$comment->{reason}]++;
		$reasonTotal++;
	}

	slashDisplay('modCommentLog', {
		mod_admin	=> getCurrentUser('seclev') > 1000,
		comments	=> $comments,
		reasonTotal	=> $reasonTotal,
		reasonHist	=> \@reasonHist,
	}, { Return => 1, Nocomm => 1 });
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
	my $user = getCurrentUser();

	# don't inherit these ...
	for (qw(sid cid pid date subject comment uid points lastmod
		reason nickname fakeemail homepage sig)) {
		$comment->{$_} = '' unless exists $comment->{$_};	
	}

	slashDisplay('linkComment', {
		%$comment, # defaults
		date		=> $date,
		pid		=> $comment->{realpid} || $comment->{pid},
		threshold	=> $comment->{threshold} || $user->{threshold},
		commentsort	=> $user->{commentsort},
		mode		=> $user->{mode},
		comment		=> $printcomment,
	}, { Return => 1, Nocomm => 1 });
}

#========================================================================

=head2 displayThread(SID, PID, LVL, COMMENTS)

Displays an entire thread.  w00p!

=over 4

=item Parameters

=over 4

=item SID

The story ID.

=item PID

The parent ID.

=item LVL

What level of the thread we're at.

=item COMMENTS

Arrayref of all our comments.

=back

=item Return value

The thread.

=item Dependencies

The 'displayThread' template block.

=back

=cut

sub displayThread {
	my($sid, $pid, $lvl, $comments, $const) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$lvl ||= 0;
	my $mode = getCurrentUser('mode');
	my $indent = 1;
	my $full = my $cagedkids = !$lvl;
	my $hidden = my $displayed = my $skipped = 0;
	my $return = '';

	if ($user->{mode} eq 'flat' || $user->{mode} eq 'archive') {
		$indent = 0;
		$full = 1;
	} elsif ($user->{mode} eq 'nested') {
		$indent = 1;
		$full = 1;
	}

	unless ($const) {
		for (map { ($_ . "begin", $_ . "end") }
			qw(table cage cagebig indent comment)) {
			$const->{$_} = getData($_, '', '');
		}
	}

	foreach my $cid (@{$comments->[$pid]{kids}}) {
		my $comment = $comments->[$cid];

		$skipped++;
		$form->{startat} ||= 0;
		next if $skipped < $form->{startat};
		$form->{startat} = 0; # Once We Finish Skipping... STOP

		if ($comment->{points} < $user->{threshold}) {
			if ($user->{is_anon} || ($user->{uid} != $comment->{uid})) {
				$hidden++;
				next;
			}
		}

		my $highlight = 1 if $comment->{points} >= $user->{highlightthresh};
		my $finish_list = 0;

		if ($full || $highlight) {
			if ($lvl && $indent) {
				$return .= $const->{tablebegin} .
					dispComment($comment) . $const->{tableend};
				$cagedkids = 0;
			} else {
				$return .= dispComment($comment);
			}
			$displayed++;
		} else {
			my $pntcmt = @{$comments->[$comment->{pid}]{kids}} > $user->{commentspill};
			$return .= $const->{commentbegin} .
				linkComment($comment, $pntcmt, 1);
			$finish_list++;
		}

		if ($comment->{kids}) {
			$return .= $const->{cagebegin} if $cagedkids;
			$return .= $const->{indentbegin} if $indent;
			$return .= displayThread($sid, $cid, $lvl+1, $comments, $const);
			$return .= $const->{indentend} if $indent;
			$return .= $const->{cageend} if $cagedkids;			
		}

		$return .= $const->{commentend} if $finish_list;

		last if $displayed >= $user->{commentlimit};
	}

	if ($hidden && ! $user->{hardthresh} && $user->{mode} ne 'archive') {
		$return .= $const->{cagebigbegin} if $cagedkids;
		my $link = linkComment({
			sid		=> $sid,
			threshold	=> $constants->{comment_minscore},
			pid		=> $pid,
			subject		=> getData('displayThreadLink', { hidden => $hidden }, '')
		});
		$return .= slashDisplay('displayThread', { 'link' => $link },
			{ Return => 1, Nocomm => 1 });
		$return .= $const->{cagebigend} if $cagedkids;
	}

	return $return;
}

#========================================================================

=head2 dispComment(COMMENT)

Displays a particular comment.

=over 4

=item Parameters

=over 4

=item COMMENT

Hashref of comment data.
If the 'no_moderation' key of the COMMENT hashref exists, the
moderation elements of the comment will not be displayed.

=back

=item Return value

The comment to display.

=item Dependencies

The 'dispComment' template block.

=back

=cut

sub dispComment {
	my($comment) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my($comment_shrunk, %reasons);

	if ($form->{mode} ne 'archive' && length($comment->{comment}) > $user->{maxcommentsize}
		&& $form->{cid} ne $comment->{cid}) {
		$comment_shrunk = balanceTags(
			chopEntity($comment->{comment}, $user->{maxcommentsize})
		);
	}

	for (0 .. @{$constants->{reasons}} - 1) {
		$reasons{$_} = $constants->{reasons}[$_];
	}

	my $can_mod = ! $comment->{no_moderation} && ! $user->{is_anon} &&
		((	$user->{willing} && $user->{points} > 0 &&
			$comment->{uid} != $user->{uid} && $comment->{lastmod} != $user->{uid}
		) || ($user->{seclev} > 99 && $constants->{authors_unlimited}));

	# don't inherit these ...
	for (qw(sid cid pid date subject comment uid points lastmod
		reason nickname fakeemail homepage sig)) {
		$comment->{$_} = '' unless exists $comment->{$_};	
	}

	slashDisplay('dispComment', {
		%$comment,
		comment_shrunk	=> $comment_shrunk,
		reasons		=> \%reasons,
		can_mod		=> $can_mod,
		is_anon		=> isAnon($comment->{uid}),
	}, { Return => 1, Nocomm => 1 });
}

###########################################################
#  Functions for dealing with Story selection and Display #
###########################################################

#========================================================================

=head2 dispStory(STORY, AUTHOR, TOPIC, FULL)

Display a story.

=over 4

=item Parameters

=over 4

=item STORY

Hashref of data about the story.

=item AUTHOR

Hashref of data about the story's author.

=item TOPIC

Hashref of data about the story's topic.

=item FULL

Boolean for show full story, or just the
introtext portion.

=back

=item Return value

Story to display.

=item Dependencies

The 'dispStory' template block.

=back

=cut


sub dispStory {
	my($story, $author, $topic, $full) = @_;
	my $constants = getCurrentStatic();
	my $form_section = getCurrentForm('section');

	my $section = getSection($story->{section});

	my %data = (
		story	=> $story,
		section => $section,
		topic	=> $topic,
		author	=> $author,
		full	=> $full,
		magic	=> (!$full && (index($story->{title}, ':') == -1)
			&& ($story->{section} ne $constants->{defaultsection})
			&& ($story->{section} ne $form_section)),
		width	=> $constants->{titlebar_width}
	);

	slashDisplay('dispStory', \%data, 1);
}

#========================================================================

=head2 displayStory(SID, FULL)

Display a story by SID (frontend to C<dispStory>).

=over 4

=item Parameters

=over 4

=item SID

Story ID to display.

=item FULL

Boolean for show full story, or just the
introtext portion.

=back

=item Return value

A list of story to display, hashref of story data,
hashref of author data, and hashref of topic data.

=back

=cut

sub displayStory {
	# caller is the pagename of the calling script
	my($sid, $full) = @_;	# , $caller  no longer needed?  -- pudge

	my $slashdb = getCurrentDB();
	my $story = $slashdb->getStory($sid);
	my $author = $slashdb->getAuthor($story->{uid},
		['nickname', 'fakeemail', 'homepage']);
	my $topic = $slashdb->getTopic($story->{tid});
	
	# convert the time of the story (this is database format) 
	# and convert it to the user's prefered format 
	# based on their preferences 

	# An interesting note... this is pretty much the
	# only reason this function is even needed. 
	# Everything else can easily be done with
	# dispStory(). Even this could be worked
	# into the logic for the template Display
	#  -Brian

	# well, also, dispStory needs a story reference, not an SID,
	# though that could be changed -- pudge

	$story->{storytime} = timeCalc($story->{'time'});

	# get extra data from section table for this story
	# (if exists)
	# this only needs to run for slashdot
	# why is this commented out?  -- pudge
	# Its basically an undocumented feature
	# that Slash uses.
	#$slashdb->setSectionExtra($full, $story);

	my $return = dispStory($story, $author, $topic, $full);
	return($return, $story, $author, $topic);
}


#========================================================================

=head2 getOlderStories(STORIES, SECTION)

Get older stories for older stories box.

=over 4

=item Parameters

=over 4

=item STORIES

Array ref of the older stories.

=item SECTION

Hashref of section data.

=back

=item Return value

The older stories.

=item Dependencies

The 'getOlderStories' template block.

=back

=cut

sub getOlderStories {
	my($stories, $section) = @_;
	my($count, $newstories, $today, $stuff);
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$stories ||= $slashdb->getNewStories($section);
	for (@$stories) {
		my($sid, $sect, $title, $time, $commentcount, $day) = @{$_}; 
		my($w, $m, $d, $h, $min, $ampm) = split m/ /, $time;
		push @$newstories, {
			sid		=> $sid,
			section		=> $sect,
			title		=> $title,
			'time'		=> $time,
			commentcount	=> $commentcount,
			day		=> $day,
			w		=> $w,
			'm'		=> $m,
			d		=> $d,
			h		=> $h,
			min		=> $min,
			ampm		=> $ampm,
			'link'		=> linkStory({
				'link'	=> $title,
				sid	=> $sid,
				section	=> $sect
			})
		};
	}

	my $yesterday = $slashdb->getDay() unless $form->{issue} > 1 || $form->{issue};
	$yesterday ||= int($form->{issue}) - 1;

	slashDisplay('getOlderStories', {
		stories		=> $newstories,
		section		=> $section,
		yesterday	=> $yesterday,
		min		=> $section->{artcount} + $form->{min},
	}, 1);
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
	my($s1, $s2)=@_;
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
sub getAnonCookie {	
	my($user) = @_;
	my $r = Apache->request;
	my $cookies = getCurrentCookie();
	if (my $cookie = $cookies->{anon}->value) {
		$user->{anon_id} = $cookie;
		$user->{anon_cookie} = 1;
	} else {
		$user->{anon_id} = getAnonId();
	}
}

########################################################
# we need to reorg this ... maybe get rid of the need for it -- pudge
sub getFormkeyId {
	my($uid) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	# this id is the key for the commentkey table, either UID or
	# unique hash key generated by IP address
	my $id;

	# if user logs in during submission of form, after getting
	# formkey as AC, check formkey with user as AC
	if ($user->{uid} > 0 && $form->{rlogin} && length($form->{upasswd}) > 1) {
		getAnonCookie($user);
		$id = $user->{anon_id};
	} elsif ($uid > 0) {
		$id = $uid;
	} else {
		$id = $user->{anon_id};
	}
	return($id);
}


########################################################
sub intervalString {
	# Ok, this isn't necessary, but it makes it look better than saying:
	#  "blah blah submitted 23333332288 seconds ago"
	my($interval) = @_;
	my $interval_string;

	if ($interval > 60) {
		my($hours, $minutes) = 0;
		if ($interval > 3600) {
			$hours = int($interval/3600);
			if ($hours > 1) {
				$interval_string = $hours . ' ' . getData('hours', '', '');
			} elsif ($hours > 0) {
				$interval_string = $hours . ' ' . getData('hour', '', '');
			}
			$minutes = int(($interval % 3600) / 60);

		} else {
			$minutes = int($interval / 60);
		}

		if ($minutes > 0) {
			$interval_string .= ", " if $hours;
			if ($minutes > 1) {
				$interval_string .= $minutes . ' ' . getData('minutes', '', '');
			} else {
				$interval_string .= $minutes . ' ' . getData('minute', '', '');
			}
		}
	} else {
		$interval_string = $interval . ' ' . getData('seconds', '', '');
	}

	return($interval_string);
}

##################################################################
sub submittedAlready {
	my($formkey, $formname) = @_;
	my $slashdb = getCurrentDB();

	# find out if this form has been submitted already
	my($submitted_already, $submit_ts) = $slashdb->checkForm($formkey, $formname)
		or errorMessage(getData('noformkey', '', '')), return;

		if ($submitted_already) {
			errorMessage(getData('submitalready', {
				interval_string => intervalString(time() - $submit_ts)
			}, ''));
		}
		return($submitted_already);
}

##################################################################
# nice little function to print out errors
sub errorMessage {
	my($error_message) = @_;
	print $error_message, "\n";
	return;
}


##################################################################
# make sure they're not posting faster than the limit
sub checkSubmission {
	my($formname, $limit, $max, $id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $formkey_earliest = time() - $constants->{formkey_timeframe};
	# If formkey starts to act up, me doing the below
	# may be the cause
	my $formkey = getCurrentForm('formkey');

	my $last_submitted = $slashdb->getSubmissionLast($id, $formname);

	my $interval = time() - $last_submitted;

	if ($interval < $limit) {
		errorMessage(getData('speedlimit', {
			limit_string	=> intervalString($limit),
			interval_string	=> intervalString($interval)
		}, ''));
		return;

	} else {
		if ($slashdb->checkTimesPosted($formname, $max, $id, $formkey_earliest)) {
			undef $formkey unless $formkey =~ /^\w{10}$/;

			unless ($formkey && $slashdb->checkFormkey($formkey_earliest, $formname, $id, $formkey)) {
				$slashdb->createAbuse("invalid form key", $ENV{REMOTE_ADDR}, $ENV{SCRIPT_NAME}, $ENV{QUERY_STRING});
				errorMessage(getData('invalidformkey', '', ''));
				return;
			}

			if (submittedAlready($formkey, $formname)) {
				$slashdb->createAbuse("form already submitted", $ENV{REMOTE_ADDR}, $ENV{SCRIPT_NAME}, $ENV{QUERY_STRING});
				return;
			}

		} else {
			$slashdb->createAbuse("max form submissions $max reached", $ENV{REMOTE_ADDR}, $ENV{SCRIPT_NAME}, $ENV{QUERY_STRING});
			errorMessage(getData('maxposts', {
				max		=> $max,
				timeframe	=> intervalString($constants->{formkey_timeframe})
			}, ''));
			return;
		}
	}
	return 1;
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
		push @$items, {
			value => slashDisplay(\$item->{value}, {}, { Return => 1, Nocomm => 1 }),
			label => slashDisplay(\$item->{label}, {}, { Return => 1, Nocomm => 1 })
		};
	}

	if (@$menu_items) {
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


#========================================================================

=head2 getData(VALUE [, PARAMETERS, PAGE])

Returns snippets of data associated with a given page.

=over 4

=item Parameters

=over 4

=item VALUE

The name of the data-snippet to process and retrieve.

=item PARAMETERS

Data stored in a hashref which is to be passed to the retrieved snippet.

=item PAGE

The name of the page to which VALUE is associated.

=back

=item Return value

Returns data snippet with all necessary data interpolated.

=item Dependencies

Gets little snippets of data, determined by the value parameter, from 
a data template. A data template is a colletion of data snippets 
in one template, which are grouped together for efficiency. Each 
script can have it's own data template (specified by the PAGE 
parameter). If PAGE is unspecified, snippets will be retrieved from
the last page visited by the user as determined by Slash::Apache::User.

=back

=cut

sub getData {
	my($value, $hashref, $page) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	my %opts = ( Return => 1, Nocomm => 1 );
	$opts{Page} = $page || 'NONE' if defined $page;
	return slashDisplay('data', $hashref, \%opts);
}

1;

__END__

=head1 BENDER'S TOP TEN MOST FREQUENTLY UTTERED WORDS

=over 4

=item 1.

ass

=item 2.

daffodil

=item 3.

shiny

=item 4.

my

=item 5.

bite

=item 6.

pimpmobile

=item 7.

up

=item 8.

yours

=item 9.

chumpette

=item 10.

chump

=back
