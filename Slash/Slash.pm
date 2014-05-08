# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash;

# BENDER: It's time to kick some shiny metal ass!

=head1 NAME

Slash - the BEAST

=head1 SYNOPSIS

	use Slash;  # figure the rest out ;-)

=head1 DESCRIPTION

Slash is the code that runs Slashdot.

=head1 FUNCTIONS

=cut

use strict;

use Symbol 'gensym';
use File::Spec::Functions;
use Time::HiRes;
use Time::Local;

use Slash::Constants ':people';
use Slash::DB;
use Slash::Display;
use Slash::Utility;

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(
	getData gensym displayStory displayRelatedStories dispStory
	getOlderStories getOlderDays getOlderDaysFromDay

	getCurrentAnonymousCoward
	getCurrentCookie
	getCurrentDB
	getCurrentForm
	getCurrentMenu
	getCurrentSkin
	getCurrentStatic
	getCurrentUser
	getCurrentVirtualUser
	getCurrentCache

	getObject

	isAnon
	isAdmin
	isSubscriber
);


# BENDER: Fry, of all the friends I've had ... you're the first.


#========================================================================

=head2 dispStory(STORY, AUTHOR, TOPIC, FULL, OTHER)

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

=item OTHER

Hash with parameters such as alternate template.

=back

=item Return value

Story to display.

=item Dependencies

The 'dispStory' template block.

=back

=cut


sub dispStory {
	my($story, $author, $topic, $full, $other) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $template_name = $other->{story_template}
		? $other->{story_template} : 'dispStory';

	# Might this logic be better off in the template? Its sole purpose
	# is aesthetics.
	$other->{magic} = !$full
			&& index($story->{title}, ':') == -1
			&& $story->{primaryskid} ne $gSkin->{skid}
			&& $story->{primaryskid} ne $constants->{mainpage_skid}
		if !exists $other->{magic};

	$other->{preview} ||= 0;
	my %data = (
		story		=> $story,
		topic		=> $topic,
		author		=> $author,
		full		=> $full,
		stid	 	=> $other->{stid},
		topics	 	=> $other->{topics_chosen},
		topiclist 	=> $other->{topiclist},
		magic	 	=> $other->{magic},
		width	 	=> $constants->{titlebar_width},
		preview  	=> $other->{preview},
		dispmode 	=> $other->{dispmode},
		dispoptions	=> $other->{dispoptions} || {},
		thresh_commentcount => $other->{thresh_commentcount},
		expandable 	=> $other->{expandable},
		getintro	=> $other->{getintro},
		fh_view         => $other->{fh_view},
	);

#use Data::Dumper; print STDERR scalar(localtime) . " dispStory data: " . Dumper(\%data);

	return slashDisplay($template_name, \%data, 1);
}

#========================================================================

=head2 displayStory(SID, FULL, OTHER)

Display a story by SID (frontend to C<dispStory>).

=over 4

=item Parameters

=over 4

=item SID

Story ID to display.

=item FULL

Boolean for show full story, or just the
introtext portion.

=item OTHER 

hash containing other parameters such as 
alternate template name, or titlebar magic.

=back

=item Return value

Rendered story

=back

=cut

sub displayStory {
	my($stoid, $full, $options, $story_cache) = @_;	

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();
	
	my $return;
	my $story;
	if ($story_cache && $story_cache->{$stoid}) {
		# If the caller passed us a ref to a cache of all the
		# story data we need, great!  Use it.
		$story = $story_cache->{$stoid};
	} elsif ($options->{force_cache_freshen}) {
		# If the caller is insisting that we go to the main DB
		# rather than using any cached data or even a reader,
		# then do that.  This is done when e.g. freshenup.pl
		# wants to write the "rendered" version of a story.
		my $slashdb = getCurrentDB();
		$story = $slashdb->getStory($stoid, "", $options->{force_cache_freshen});
		$story->{is_future} = 0;
	} else {
		# The above don't apply;  just use a reader (and maybe
		# its cache will save a trip to the actual DB).
		$story = $reader->getStory($stoid);
	}

	# There are many cases when we'd not want to return the pre-rendered text
	# from the DB.
	#
	# XXXNEWINDEX - Currently don't have a rendered copy for brief mode
	#               This is probably okay since brief mode contains basically
	#               the same info as storylinks which is generated dynamically
	#               and different users will have different links / threshold counts

	if (	   !$constants->{no_prerendered_stories}
		&& $constants->{cache_enabled}
		&& $story->{rendered} && !$options->{force_cache_freshen}
		&& !$form->{simpledesign} && !$user->{simpledesign}
		&& !$form->{lowbandwidth} && !$user->{lowbandwidth}
		&& !$form->{pda} && !$user->{pda} 
		&& (!$form->{ssi} || $form->{ssi} ne 'yes')
		&& !$user->{noicons}
		&& !$form->{issue}
		&& $gSkin->{skid} == $constants->{mainpage_skid}
		&& !$full
		&& !$options->{is_future}	 # can $story->{is_future} ever matter?
		&& ($options->{mode} && $options->{mode} ne "full")
		&& (!$options->{dispmode} || $options->{dispmode} ne "brief")
	) {
		$return = $story->{rendered};
	} else {

		my $author = $reader->getAuthor($story->{uid},
				['nickname', 'fakeemail', 'homepage']);
		my $topic = $reader->getTopic($story->{tid});
		$story->{atstorytime} = "__TIME_TAG__";

		if (!$options->{dispmode} || $options->{dispmode} ne "brief" || $options->{getintro}) {
			$story->{introtext} = parseSlashizedLinks($story->{introtext});
			$story->{introtext} = processSlashTags($story->{introtext});
		}

		if ($full) {
			$story->{bodytext} = parseSlashizedLinks($story->{bodytext});
			$story->{bodytext} = processSlashTags($story->{bodytext}, { break => 1 });
			$options->{topiclist} = $reader->getTopiclistForStory($story->{sid});
			# if a secondary page, put bodytext where introtext would normally go
			# maybe this is not the right thing, but is what we are doing for now;
			# let me know if you have another idea -- pudge
			$story->{introtext} = delete $story->{bodytext} if $form->{pagenum} > 1;
		}

		$return = dispStory($story, $author, $topic, $full, $options);

	}

	if (!$options->{force_cache_freshen}) {
		# Only do the following if force_cache_freshen is not set:
		# as it is by freshenup.pl when (re)building the 'rendered'
		# cached data for a story.
		my $is_old = $user->{mode} eq 'archive' || ($story->{is_archived} eq 'yes' && $user->{is_anon});
		my $df = $is_old ? $constants->{archive_dateformat} : '';
		my $atstorytime;
		if ($options->{is_future} && !($user->{author} || $user->{is_admin})) {
			$atstorytime = $constants->{subscribe_future_name};
		} else {
			$atstorytime = $user->{aton} . ' '
				. timeCalc($story->{'time'}, $df, undef, { is_old => $is_old });
		}
		$return =~ s/\Q__TIME_TAG__\E/$atstorytime/;
	}

	return $return;
}

#========================================================================

sub displayRelatedStories {
	my($stoid, $options) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();
	my $return = "";
	my $fh_view = $options->{fh_view} || '';

	my $related = $reader->getRelatedStoriesForStoid($stoid);

	foreach my $rel (@$related) {
		if ($rel->{rel_sid}) {
			my $viewable = $reader->checkStoryViewable($rel->{rel_sid});
			next if !$viewable;
			my $related_story = $reader->getStory($rel->{rel_sid});
			$return .= displayStory($related_story->{stoid}, 0, { dispmode => "brief", getintro => 1, expandable => 1, fh_view => $fh_view});
		} elsif ($rel->{cid}) {
			my $comment = $reader->getComment($rel->{cid});
			my $discussion = $reader->getDiscussion($comment->{sid});
			my $comment_user = $reader->getUser($comment->{uid});
			my $is_anon = isAnon($comment->{uid});
			$return .= slashDisplay("comment_related", { comment => $comment, comment_user => $comment_user, discussion => $discussion, is_anon => $is_anon }, { Return => 1});
		} elsif ($rel->{title}) {
			$return .= slashDisplay("url_related", { title => $rel->{title}, url => $rel->{url} }, { Return => 1 });
		}
	}
	return $return;
}


#========================================================================

=head2 getOlderStories(STORIES, SECTION)

Get older stories for older stories box.

=over 4

=item Parameters

=over 4

=item STORIES

Array ref of the "essentials" of the stories to display, retrieved from
getStoriesEssentials.

=item SECTION

Section name or Hashref of section data.

=back

=item Return value

The older stories, formatted.

=item Dependencies

The 'getOlderStories' template block.

=back

=cut

sub getOlderStories {
	my($stories, $section, $stuff) = @_;
	my($count, $newstories);
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	for my $story (@$stories) {
		# Use one call and parse it, it's cheaper :) -Brian
		my($day_of_week, $month, $day, $secs) =
			split m/ /, timeCalc($story->{time}, "%A %B %d %s");
		$day =~ s/^0//;
		$story->{day_of_week} = $day_of_week;
		$story->{month} = $month;
		$story->{day} = $day;
		$story->{secs} = $secs;
		$story->{issue} ||= timeCalc($story->{time}, '%Y%m%d');
		$story->{'link'} = linkStory({
			'link'  => $story->{title},
			sid     => $story->{sid},
			tid     => $story->{tid},
			section => $story->{section},
		});
	}

	my($today, $tomorrow, $yesterday, $week_ago) = getOlderDays($form->{issue});

	$form->{start} ||= 0;

	my $artcount = $user->{is_anon} ? $section->{artcount} : $user->{maxstories};
	$artcount ||= 0;

	# The template won't display all of what's passed to it (by default
	# only the first $section->{artcount}).  "start" is just an offset
	# that gets incremented.
	slashDisplay('getOlderStories', {
		stories		=> $stories,
		section		=> $section,
		cur_time	=> time,
		today		=> $today,
		tomorrow	=> $tomorrow,
		yesterday	=> $yesterday,
		week_ago	=> $week_ago,
		start		=> int($artcount/3) + $form->{start},	
		first_date	=> $stuff->{first_date},
		last_date	=> $stuff->{last_date}
	}, 1);
}

#========================================================================
sub getOlderDays {
	my($issue) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my($today, $tomorrow, $yesterday, $week_ago);
	# week prior to yesterday (oldest story we'll get back when we do
	# a getStoriesEssentials for yesterday's issue)
	if ($issue) {
		my($y, $m, $d) = $issue =~ /^(\d\d\d\d)(\d\d)(\d\d)$/;
		if ($y) {
			$today    = $reader->getDay(0);
			$tomorrow = timeCalc(scalar localtime(
				timelocal(0, 0, 12, $d, $m - 1, $y - 1900) + 86400
			), '%Y%m%d', 0);
			$yesterday = timeCalc(scalar localtime(
				timelocal(0, 0, 12, $d, $m - 1, $y - 1900) - 86400
			), '%Y%m%d', 0);
			$week_ago  = timeCalc(scalar localtime(
				timelocal(0, 0, 12, $d, $m - 1, $y - 1900) - 86400 * 8 
			), '%Y%m%d', 0);
		}
	} else {
		$today     = $reader->getDay(0);
		$tomorrow  = $reader->getDay(-1);
		$yesterday = $reader->getDay(1);
		$week_ago  = $reader->getDay(8);
	}
	return($today, $tomorrow, $yesterday, $week_ago);
}

sub getOlderDaysFromDay {
	my($day, $start, $end, $options) = @_;
	my $slashdb = getCurrentDB();
	$day     ||= $slashdb->getDay(0, $options);
	$start   ||= 0;
	$end     ||= 0;
	$options ||= {};
	my $days = [];

	$options->{orig_day} ||= $day;

	my $today = $slashdb->getDay(0, $options);

	for ($start..$end) {
		my $the_day = $slashdb->getDayFromDay($day, $_, $options);
		next if $the_day eq $today && $options->{skip_add_today} && !$options->{force};

		if (($the_day lt $today) || $options->{show_future_days}) {
			push @$days, $the_day; 
		}
	}

	if (@$days && $today gt $days->[0] && !$options->{skip_add_today}) {
		unshift @$days, "$today";
	}

	return getFormatFromDays($days, $options);
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
script can have its own data template (specified by the PAGE
parameter). If PAGE is unspecified, snippets will be retrieved from
the last page visited by the user as determined by Slash::Apache::User.

=item Notes

This is in Slash.pm instead of Slash::Utility because it depends on Slash::Display,
which also depends on Slash::Utility.  Slash::Utility can call Slash::getData
(note package name), because Slash.pm should always be loaded by scripts first
before loading Slash::Utility, so as long as nothing in Slash::Utility requires
getData for compilation, we should be good (except, note that the environment
Slash::Display depends on needs to be there, so you can't call getData before
createCurrentDB and friends are called ... see note in prepareUser).

=back

=cut

sub getData {
	my($value, $hashref, $page) = @_;
	my $cache = getCurrentCache();
	_dataCacheRefresh($cache);

	$hashref ||= {};
	$hashref->{value} = $value;
	$hashref->{returnme} = {};
	my $opts = { Return => 1, Nocomm => 1 };
	$opts->{Page} = $page || 'NONE' if defined $page;
	my $opts_getname = $opts; $opts_getname->{GetName} = 1;

	my $name = slashDisplayName('data', $hashref, $opts_getname);
	return undef if !$name || !$name->{tempdata} || !defined($name->{tempdata}{tpid});
	my $var  = $cache->{getdata}{ $name->{tempdata}{tpid} } ||= { };

	if (defined $var->{$value}) {
		# restore our original values; this is done if
		# slashDisplay is called, but it is not called here -- pudge
		my $user = getCurrentUser();
		$user->{currentSkin}	= $name->{origSkin};
		$user->{currentPage}	= $name->{origPage};

		return $var->{$value};
	}

	my $str = slashDisplay($name, $hashref, $opts);
	return undef if !defined($str);

	if ($hashref->{returnme}{data_constant}) {
		$cache->{getdata}{_last_refresh} ||= time;
		$var->{$value} = $str;
	}
	return $str;
}

sub _dataCacheRefresh {
	my($cache) = @_;
	if (($cache->{getdata}{_last_refresh} || 0)
		< time - ($cache->{getdata}{_expiration} || 0)) {
		$cache->{getdata} = {};
		$cache->{getdata}{_last_refresh} = time;
		$cache->{getdata}{_expiration} = getCurrentStatic('block_expire');
	}
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
