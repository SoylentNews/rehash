#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use Time::HiRes;
use Slash::Slashboxes;

sub main {
my $start_time = Time::HiRes::time;
	my $constants	= getCurrentStatic();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
	my $slashdb	= getCurrentDB();
	my $reader	= getObject('Slash::DB', { db_type => 'reader' });

	return if redirect_home_if_necessary();

	my($stories, $Stories); # could this be MORE confusing please? kthx

	# why is this commented out?  -- pudge
	# $form->{mode} = $user->{mode} = "dynamic" if $ENV{SCRIPT_NAME};

	# Handle moving a block up or down, or removing it.
	if ($form->{bid} && $form->{op} && $form->{op} =~ /^[udx]$/) {
		   if ($form->{op} eq 'u') { upBid($form->{bid}) }
		elsif ($form->{op} eq 'd') { dnBid($form->{bid}) }
		else                       { rmBid($form->{bid}) }
		redirect($ENV{HTTP_REFERER} || $ENV{SCRIPT_NAME});
		return;
	}

	my $rss = $constants->{rss_allow_index}
		&& $form->{content_type} && $form->{content_type} =~ $constants->{feed_types}
		&& (
			   $user->{is_admin}
			|| ($constants->{rss_allow_index} > 1 && $user->{is_subscriber})
			|| ($constants->{rss_allow_index} > 2 && !$user->{is_anon})
			|| ($constants->{rss_allow_index} > 3 )
		);

	# $form->{logtoken} is only allowed if using rss
	if ($form->{logtoken} && !$rss) {
		redirect($ENV{SCRIPT_NAME});
	}

	my $skin_name = $form->{section};
	my $skid = determineCurrentSkin();
	my $gSkin = getCurrentSkin();
	$skin_name = $gSkin->{name};

# XXXSKIN I'm turning custom numbers of maxstories off for now, so all
# users get the same number.  This will improve query cache hit rates and 
# right now we need all the edge we can get.  Hopefully we can get this 
# back on soon. - Jamie 2004/07/17
#	my $user_maxstories = $user->{maxstories};
#	my $user_maxstories = getCurrentAnonymousCoward("maxstories");

	# Decide what our issue is going to be.
	my $limit;
	my $issue = $form->{issue} || '';
	$issue = '' if $issue !~ /^\d{8}$/;
#	if ($issue) {
#		if ($user->{is_anon}) {
#			$limit = $gSkin->{artcount_max} * 3;
#		} else {
#			$limit = $user_maxstories * 7;
#		}
#	} elsif ($user->{is_anon}) {
#		$limit = $gSkin->{artcount_max};
#	} else {
#		$limit = $user_maxstories;
#	}

	my $gse_hr = { };
	# Set the characteristics that stories can be in to appear.  This
	# is a simple list:  the current skin's nexus, and then if the
	# current skin is the mainpage, add in the list of nexuses that
	# the mainpage needs the user's story_always_topic
	# and story_always_nexus tids.
	# It's pretty ugly that this duplicates some of the effect of
	# getDispModesForStories().  This code really should be
	# simplified and consolidated.
	$gse_hr->{tid} = [ $gSkin->{nexus} ];
	if ($gSkin->{skid} == $constants->{mainpage_skid}) {
		# This may or may not be necessary;  gSE() should
		# already know to do this.  But it should not hurt
		# to add the tids here.
		if ($constants->{brief_sectional_mainpage}) {
			my $nexus_children = $reader->getMainpageDisplayableNexuses();
			push @{$gse_hr->{tid}}, @$nexus_children;
		}

		my @extra_tids = split ",", $user->{story_always_topic};
		push @extra_tids, split ",", $user->{story_always_nexus};
		# Let gse know that we're asking for extra tids beyond
		# those expected by default.  
		if (@extra_tids) {
			$gse_hr->{tid_extras} = 1;
			push @{$gse_hr->{tid}}, @extra_tids;
		}

		# Eliminate duplicates and sort.
		my %tids = ( map { ($_, 1) } @{$gse_hr->{tid}} );
		$gse_hr->{tid} = [ keys %tids ];
	}
	@{ $gse_hr->{tid} } = sort { $a <=> $b } @{ $gse_hr->{tid} };

	# Now exclude characteristics.  One tricky thing here is that
	# we never exclude the nexus for the current skin -- if the user
	# went to foo.sitename.com explicitly, then they're going to see
	# stories about foo, regardless of their prefs.  Another tricky
	# thing is that story_never_topic doesn't get used unless a var
	# and/or this user's subscriber status are set a particular way.
	my @never_tids = split /,/, $user->{story_never_nexus};
	if ($constants->{story_never_topic_allow} == 2
		|| ($user->{is_subscriber} && $constants->{story_never_topic_allow} == 1)
	) {
		push @never_tids, split /,/, $user->{story_never_topic};
	}
	@never_tids =
		grep { /^'?\d+'?$/ && $_ != $gSkin->{nexus} }
		@never_tids;
	$gse_hr->{tid_exclude} = [ @never_tids ] if @never_tids;
	$gse_hr->{uid_exclude} = [ split /,/, $user->{story_never_author} ]
		if $user->{story_never_author};

# For now, all users get the same number of maxstories.
#	$gse_hr->{limit} = $user_maxstories if $user_maxstories;

	$gse_hr->{issue} = $issue if $issue;
	my $gse_db = rand(1) < $constants->{index_gse_backup_prob} ? $reader : $slashdb;
	$stories = $gse_db->getStoriesEssentials($gse_hr);

	# Workaround for a bug in saving/updating.  Sometimes a story
	# will be saved with neverdisplay=1 but with an incorrect
	# story_topics_rendered row that places it in a nexus as well.
	# Until we figure out why, there's additional logic here to
	# make sure we screen out neverdisplay stories. -Jamie 2007-08-06
	my $stoid_in_str = join(',', map { $_->{stoid} } @$stories);
	my $nd_hr = { };
	if ($stoid_in_str) {
		$nd_hr = $gse_db->sqlSelectAllKeyValue('stoid, value',
			'story_param',
			qq{stoid IN ($stoid_in_str) AND name='neverdisplay'});
		if (keys %$nd_hr) {
			for my $story_hr (@$stories) {
				$story_hr->{neverdisplay} = 1 if $nd_hr->{ $story_hr->{stoid} };
			}
		}
	}
	if (grep { $_->{neverdisplay} } @$stories) {
		require Data::Dumper; $Data::Dumper::Sortkeys = 1;
		my @nd_ids = map { $_->{stoid} } grep { $_->{neverdisplay} } @$stories;
		my $gse_str = Data::Dumper::Dumper($gse_hr); $gse_str =~ s/\s+/ /g;
		##########
		# TMB We don't need this in the logs constantly.
		#print STDERR scalar(gmtime) . " index.pl ND story '@nd_ids' returned by gSE called with params: '$gse_str'\n";
		$stories = [ grep { !$_->{neverdisplay} } @$stories ];
	}

	# A kludge to keep Politics stories off the mainpage.  The
	# proper fix would be to redesign story_topics_rendered to
	# include a weight in the (stoid,nexus_tid) tuple, and to
	# have gSE only select stories from its nexus list with that
	# weight or higher.  Instead I've been asked to hardcode
	# an "offmainpage" boolean at story save time which will be
	# checked at story display time. -Jamie 2008-01-25
	if ($gSkin->{skid} == $constants->{mainpage_skid}) {
		my $om_hr = { };
		if ($stoid_in_str) {
			$om_hr = $gse_db->sqlSelectAllKeyValue('stoid, value',
				'story_param',
				qq{stoid IN ($stoid_in_str) AND name='offmainpage' AND value != 0});
			if (keys %$om_hr) {
				for my $story_hr (@$stories) {
					$story_hr->{offmainpage} = 1 if $om_hr->{ $story_hr->{stoid} };
				}
			}
		}
		# XXX should only grep a story out if the story has
		# NO nexuses that the user has requested appear in
		# full on the mainpage
		$stories = [ grep { !$_->{offmainpage} } @$stories ];
	}

	#my $last_mainpage_view;
	#$last_mainpage_view = $slashdb->getTime() if $gSkin->{nexus} == $constants->{mainpage_skid} && !$user->{is_anon};

#use Data::Dumper;
#print STDERR "index.pl gse_hr: " . Dumper($gse_hr);
#print STDERR "index.pl gSE stories: " . Dumper($stories);

	# We may, in this listing, have a story from the Mysterious Future.
	# If so, there are three possibilities:
	# 1) This user is a subscriber, in which case they see it (and its
	#    timestamp gets altered to the MystFu text)
	# 2) This user is not a subscriber, but is logged-in, and logged-in
	#    non-subscribers are allowed to *know* that there is such a
	#    story without being able to see it, so we make them aware.
	# 3) This user is not a subscriber, and non-subscribers are not
	#    to be made aware of this story's existence, so ignore it.
	my $future_plug = 0;

	# Is there a story in the Mysterious Future?
	my $is_future_story = 0;
	$is_future_story = 1 if @$stories # damn you, autovivification!
		&& $stories->[0]{is_future};

	# Do we want to display the plug saying "there's a future story,
	# subscribe and you can see it"?  Yes if the user is logged-in
	# but not a subscriber, but only if the first story is actually
	# in the future.  If the user has a daypass, they don't get this
	# either.  Just check the first story;  they're in order.
	if ($is_future_story
		&& !$user->{is_subscriber}
		&& !$user->{has_daypass}
		&& !$user->{is_anon}
		&& $constants->{subscribe_future_plug}) {
		$future_plug = 1;
	}

	return do_rss($reader, $constants, $user, $form, $stories, $gSkin) if $rss;

	# Do we want to display the plug offering the user a daypass?
	my $daypass_plug_text = '';
	if ($constants->{daypass}) {
		# If this var is set, only offer a daypass when there
		# is a future story available.
		if (!$constants->{daypass_offer_onlywhentmf}
			|| $is_future_story) {
			my $daypass_db = getObject('Slash::Daypass', { db_type => 'reader' });
			my $do_offer = $daypass_db->doOfferDaypass();
			if ($do_offer) {
				$daypass_plug_text = $daypass_db->getOfferText();
				# On days where a daypass is being offered, for
				# users who are eligible, we give them that
				# message instead of (not in addition to) the
				# "please subscribe" message.
				$future_plug = 0;
			}
		}
	}

#	# See comment in plugins/Journal/journal.pl for its call of
#	# getSkinColors() as well.
#	$user->{currentSection} = $section->{section};
	Slash::Utility::Anchor::getSkinColors();

	# displayStories() pops stories off the front of the @$stories array.
	# Whatever's left is fed to displaySlashboxes for use in the
	# index_more block (aka Older Stuff).
	# We really should make displayStories() _return_ the leftover
	# stories as well, instead of modifying $stories in place to just
	# suddenly mean something else.
	my $linkrel = {};
	$Stories = displayStories($stories, $linkrel);

	# damn you, autovivification!
	my($first_date, $last_date);
	if (@$stories) {
		($first_date, $last_date) = ($stories->[0]{time}, $stories->[-1]{time});
		$first_date =~ s/(\d\d\d\d)-(\d\d)-(\d\d).*$/$1$2$3/;
		$last_date  =~ s/(\d\d\d\d)-(\d\d)-(\d\d).*$/$1$2$3/;
	}

	my $StandardBlocks = displaySlashboxes($gSkin, $stories,
		{ first_date => $first_date, last_date => $last_date }
	);

	my $title = getData('head', { skin => $skin_name });
	header({ title => $title, link => $linkrel }, $skin_name) or return;


	my $metamod_elig = 0;
	if ($constants->{m2}) {
		my $metamod_reader = getObject('Slash::Metamod', { db_type => 'reader' });
		$metamod_elig = $metamod_reader->metamodEligible($user);
	}
	my $return_url = $gSkin->{rootdir};
	
	slashDisplay('index', {
		metamod_elig	=> $metamod_elig,
		future_plug	=> $future_plug,
		daypass_plug_text => $daypass_plug_text,
		stories		=> $Stories,
		boxes		=> $StandardBlocks,
		return_url  => $return_url,
	});

	footer();
	#$slashdb->setUser($user->{uid}, { 'last_mainpage_view' => $last_mainpage_view }) if $last_mainpage_view;
	writeLog($skin_name);

#	{
#		use Proc::ProcessTable;
#		my $t = new Proc::ProcessTable;
#		my $procs = $t->table();
#		PROC: for my $proc (@$procs) {
#			my $pid = $proc->pid();
#			next unless $pid == $$;
#			my $size = $proc->size();
#
#			if ($size > 10_000_000) {
#				my $mb = sprintf("%.2f", $size/1_000_000);
#				print STDERR "pid $$ VSZ $mb MB: just finished op '$form->{op}' sid '$form->{sid}' issue '$form->{issue}' skid '$gSkin->{skid}' uid '$user->{uid}'\n";
#				last PROC;
#			}
#		}
#	}

}

# Slash::Apache::User can turn a "/" request into an index.pl request
# if the user has index_classic set or the user-agent is MSIE 6.
# So, since this already is index.pl, be sure not to redirect to
# "/" if either of those things is true, since that would be an
# infinite redirection loop.

sub redirect_home_if_necessary {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $script = '';
	if (!$user->{is_anon} && defined $form->{usebeta}) {
		my $usebeta = $form->{usebeta} eq '1';
		my $index_classic = $usebeta ? undef : 1;
		if ($user->{index_classic} xor $index_classic) {
			my $slashdb = getCurrentDB();
			$slashdb->setUser($user->{uid}, { index_classic => $index_classic });
			$user->{index_classic} = $index_classic;
		}
		$script = '/' if $usebeta
			&& !$form->{content_type}
			&& $ENV{HTTP_USER_AGENT} !~ /MSIE [2-6]/;
	}

	if (       $form->{op} && $form->{op} eq 'userlogin' && !$user->{is_anon}
		|| $form->{upasswd}
		|| $form->{unickname}
	) {
		# Any login attempt, successful or not, gets
		# redirected to the homepage, to avoid keeping
		# the password or nickname in the query_string of
		# the URL (this is a security risk via "Referer").
		# (If we've determined the user needs to go to
		# index2.pl, send them there.)  Note that
		# $form->{returnto} is processed by
		# Slash::Apache::User::handler, which for reasons
		# of a mysterious bug defers the actual redirect
		# to be handled by this script.
		$script = $form->{returnto} || '/';
	}

	if ($script) {
		redirect($script);
		return 1;
	}
	return 0;
}

sub getDispModesForStories {
	my($stories, $stories_data_cache, $user, $modes, $story_to_dispmode_hr) = @_;

	my @story_always_topic =	split (',', $user->{story_always_topic});
	my @story_always_nexus =	split (',', $user->{story_always_nexus});
	my @story_full_brief_nexus =	split (',', $user->{story_full_brief_nexus});
	my @story_brief_always_nexus =	split (',', $user->{story_brief_always_nexus});
	my @story_full_best_nexus =	split (',', $user->{story_full_best_nexus});
	my @story_brief_best_nexus =	split (',', $user->{story_brief_best_nexus});

	my(%mp_dispmode_nexus, %sec_dispmode_nexus);
	$mp_dispmode_nexus{$_}  = $modes->[0] foreach (@story_always_nexus, @story_full_brief_nexus, @story_full_best_nexus);
	$mp_dispmode_nexus{$_}  = $modes->[1] foreach (@story_brief_best_nexus, @story_brief_always_nexus);
	$sec_dispmode_nexus{$_} = $modes->[2] foreach (@story_always_nexus);
	$sec_dispmode_nexus{$_} = $modes->[3] foreach (@story_full_brief_nexus, @story_brief_always_nexus);
	$sec_dispmode_nexus{$_} = $modes->[4] foreach (@story_full_best_nexus, @story_brief_best_nexus);

	$story_to_dispmode_hr ||= {};

	# Filter out any story we're planning on skipping up front
	@$stories = grep { getDispModeForStory($_, $stories_data_cache->{$_->{stoid}}, \%mp_dispmode_nexus, \%sec_dispmode_nexus, \@story_always_topic, $story_to_dispmode_hr) ne "none" } @$stories;
}


sub getDispModeForStory {
	my($story, $story_data, $mp_dispmode_nexus_hr, $sec_dispmode_nexus_hr, $always_topic_ar, $dispmode_hr) = @_;
	my $constants = getCurrentStatic();
	my $gSkin     = getCurrentSkin();
	my $slashdb   = getCurrentDB();
	my $skins     = $slashdb->getSkins();
	my $dispmode;

	# sometimes this is uninit ...
	my $ps_nexus = $skins->{$story->{primaryskid}}->{nexus};

	if ($gSkin->{nexus} != $constants->{mainpage_nexus_tid}) {
		$dispmode_hr->{$story->{stoid}} = "full" if $dispmode_hr;
		return "full";
	}

	# XXXNEWINDEX :  Right now we do our best to handle this -- there is no user pref
	# to select whether a user wants to see this in brief vs full mode.  For
	# now we just return "full"  (individual non-nexus topic selection isn't used on
	# Slashdot currently)
	foreach (@$always_topic_ar) {
		$dispmode_hr->{$story->{stoid}} = "full" if $dispmode_hr;
		return "full" if $story_data->{story_topics_rendered}{$_};
	}


	if ($story_data->{story_topics_rendered}{$constants->{mainpage_nexus_tid}}) {
		$dispmode = $mp_dispmode_nexus_hr->{$ps_nexus};
		$dispmode_hr->{$story->{stoid}} = $dispmode if $dispmode_hr && $dispmode;
		return $dispmode if $dispmode;
		$dispmode_hr->{$story->{stoid}} = "full" if $dispmode_hr;
		return "full";
	}

	# Sectional Story -- decide what we should do with it
	$dispmode = $sec_dispmode_nexus_hr->{$ps_nexus};
	$dispmode_hr->{$story->{stoid}} = $dispmode if $dispmode_hr && $dispmode;
	return $dispmode if $dispmode;
	
	# preference for sectional not defined -- go with default for site
	if ($constants->{brief_sectional_mainpage}) {
		$dispmode_hr->{$story->{stoid}} = "brief" if $dispmode_hr;
		return "brief";
	} else {
		$dispmode_hr->{$story->{stoid}} = "none" if $dispmode_hr;
		return "none";
	}
	
}


sub do_rss {
	my($reader, $constants, $user, $form, $stories, $gSkin) = @_;
	my @rss_stories;

	my @stoids_for_cache =
		map { $_->{stoid} }
		@$stories;
	my $stories_data_cache;
	$stories_data_cache = $reader->getStoriesData(\@stoids_for_cache)
		if @stoids_for_cache;

	getDispModesForStories($stories, $stories_data_cache, $user, [qw(full none full none none)]);


	for (@$stories) {
		my $story = $reader->getStory($_->{sid});
		$story->{introtext} = parseSlashizedLinks($story->{introtext});
		$story->{introtext} = processSlashTags($story->{introtext});
		$story->{introtext} =~ s{(HREF|SRC)\s*=\s*"(//[^/]+)}
		                        {$1 . '="' . url2abs($2)}sieg;
		push @rss_stories, { story => $story };
	}

	my $title = getData('rsshead', { skin_title => $gSkin->{title}, skid => $gSkin->{skid} });
	my $name = lc($gSkin->{basedomain}) . '.' . $form->{content_type};

	xmlDisplay($form->{content_type} => {
		channel	=> {
			title	=> $title,
		},
		version 		=> $form->{rss_version},
		image			=> 1,
		items			=> \@rss_stories,
		rdfitemdesc		=> 1,
		rdfitemdesc_html	=> 1,
	}, {
		filename		=> $name,
	});

	writeLog($gSkin->{name});
	return;
}

#################################################################
# Should this method be in the DB library?
# absolutely.  we should hide the details there.  but this is in a lot of
# places (modules, index, users); let's come back to it later.  -- pudge
sub saveUserBoxes {
	my(@slashboxes) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	return if $user->{is_anon};
	$user->{slashboxes} = join ",", @slashboxes;
	$slashdb->setUser($user->{uid},
		{ slashboxes => $user->{slashboxes} });
}

#################################################################
sub upBid {
	my($bid) = @_;
	my @a = getUserSlashboxes();
	# Build the %order hash with the order in the values.
	my %order = ( );
	for my $i (0..$#a) {
		$order{$a[$i]} = $i;
	}
	# Reduce the value of the block that's reordered.
	$order{$bid} -= 1.5;
	# Resort back into the new order.
	@a = sort { $order{$a} <=> $order{$b} } keys %order;
	saveUserBoxes(@a);
}

#################################################################
sub dnBid {
	my($bid) = @_;
	my @a = getUserSlashboxes();
	# Build the %order hash with the order in the values.
	my %order = ( );
	for my $i (0..$#a) {
		$order{$a[$i]} = $i;
	}
	# Increase the value of the block that's reordered.
	$order{$bid} += 1.5;
	# Resort back into the new order.
	@a = sort { $order{$a} <=> $order{$b} } keys %order;
	saveUserBoxes(@a);
}

#################################################################
sub rmBid {
	my($bid) = @_;
	my @a = getUserSlashboxes();
	@a = grep { $_ ne $bid } @a;
	saveUserBoxes(@a);
}

#################################################################
# pass it how many, and what.
sub displayStories {
	my($stories, $linkrel) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();
	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();
	my $ls_other  = { user => $user, reader => $reader, constants => $constants };
	my($today, $x) = ('', 0);

	
# XXXSKIN I'm turning custom numbers of maxstories off for now, so all
# users get the same number.  This will improve query cache hit rates and 
# right now we need all the edge we can get.  Hopefully we can get this 
# back on soon. - Jamie 2004/07/17
#       my $user_maxstories = $user->{maxstories};
# Here, maxstories should come from the skin, and $cnt should be
# named minstories and that should come from the skin too.
	my $user_maxstories = getCurrentAnonymousCoward("maxstories");
	my $cnt = $gSkin->{artcount_min};
	my($return, $counter);

	# get some of our constant messages but do it just once instead
	# of for every story
	my $msg;
	$msg->{readmore} = getData('readmore');
	if ($constants->{body_bytes}) {
		$msg->{bytes} = getData('bytes');
	} else {
		$msg->{words} = getData('words');
	}

	# Pull the story data we'll be needing into a cache all at once,
	# to avoid making multiple calls to the DB.
#	my $n_future_stories = scalar grep { $_->{is_future} } @$stories;
#	my $n_for_cache = $cnt + $n_future_stories;
#	$n_for_cache = scalar(@$stories) if $n_for_cache > scalar(@$stories);
	my @stoids_for_cache =
		map { $_->{stoid} }
		@$stories;
#	@stoids_for_cache = @stoids_for_cache[0..$n_for_cache-1]
#		if $#stoids_for_cache > $n_for_cache;
	my $stories_data_cache;
	$stories_data_cache = $reader->getStoriesData(\@stoids_for_cache)
		if @stoids_for_cache;

	my $dispmodelast = "";
	my $story_to_dispmode_hr = {};

	getDispModesForStories($stories, $stories_data_cache, $user, [qw(full brief full brief none)], $story_to_dispmode_hr);

	# Shift them off, so we do not display them in the Older Stuff block
	# later (this simulates the old cursor-based method from circa 1997
	# which was actually not all that smart, but umpteen layers of caching
	# makes it quite tolerable here in 2004 :)
	my $story;
	STORIES_DISPLAY: while ($story = shift @$stories) {
		my($tmpreturn, $other, @links);

		$other->{dispmode} = $story_to_dispmode_hr->{$story->{stoid}};

		# This user may not be authorized to see future stories;  if so,
		# skip them.
		if ($story->{is_future}) {
			# If subscribers are allowed to see 0 seconds into the
			# future, future stories are off-limits.
			next if !$constants->{subscribe_future_secs};
			# If the user is a subscriber or has a daypass, the
			# is_subscriber field will be set.  If that field is
			# not set, future stories are off-limits.
			next if !$user->{is_subscriber} && !$user->{has_daypass};
			# If the user is only an honorary subscriber because
			# they have a daypass, and honorary subscribers don't
			# get to see The Mysterious Future, future stories are
			# off-limits.
			next if !$user->{is_subscriber} && $user->{has_daypass}
				&& !$constants->{daypass_seetmf};
		}

		# Check the day this story was posted (in the user's timezone).
		# Compare it to what we believe "today" is (which will be the
		# first eligible story in this list).  If this story's day is
		# not "today", and if we've already displayed enough stories
		# to sufficiently fill the homepage (typically 10), then we're
		# done -- put the story back on the list (so it'll correctly
		# appear in the Older Stuff box) and exit.
		my $day = timeCalc($story->{time}, '%A %B %d');
		my($w) = join ' ', (split / /, $day)[0 .. 2];
		$today ||= $w;
		if (++$x > $cnt && $today ne $w) {
			unshift @$stories, $story;
			last;
		}

		my @threshComments = split /,/, $story->{hitparade};  # posts in each threshold

		$other->{is_future} = 1 if $story->{is_future};

		#$other->{dispoptions}{new} = 1 if !$user->{is_anon} && $user->{last_mainpage_view} && $gSkin->{nexus} == $constants->{mainpage_skid} && $user->{last_mainpage_view} lt $story->{time};
	
		my $story_data = $stories_data_cache->{$story->{stoid}};
		
		$tmpreturn .= getData("briefarticles_begin")
			if $other->{dispmode} && $other->{dispmode} eq "brief"
				&& $dispmodelast ne "brief";
		$tmpreturn .= getData("briefarticles_end")
			if $dispmodelast eq "brief"
				&& !( $other->{dispmode} && $other->{dispmode} eq "brief" );


		$tmpreturn .= displayStory($story->{sid}, '', $other, $stories_data_cache);
		
		if ($other->{dispmode} eq "full") {
			my $readmore = $msg->{readmore};
			if ($constants->{index_readmore_with_bytes}) {
				my $readmore_data = {};
				if ($story->{body_length}) {
					if ($constants->{body_bytes}) {
						$readmore_data->{bytes} = $story->{body_length};
					} else {
						$readmore_data->{words} = $story->{word_count};
					}
					$readmore = getData('readmore_with_bytes', $readmore_data );
				}
			}

			push @links, linkStory({
				'link'		=> $readmore,
				sid		=> $story->{sid},
				tid		=> $story->{tid},
				skin		=> $story->{primaryskid},
				class		=> 'more'
			}, '', $ls_other);
			my $link;

			if ($constants->{body_bytes}) {
				$link = "$story->{body_length} $msg->{bytes}";
			} else {
				$link = "$story->{word_count} $msg->{words}";
			}

			#for some reason, this next created a hyperlink for extended copy with 'mode=nocomment'
			#if this is needed, insert mode => 'nocomment', after tid
			#mattie_p
	
			if (!$constants->{index_readmore_with_bytes}) {
				push @links, linkStory({
					'link'		=> $link,
					sid		=> $story->{sid},
					tid		=> $story->{tid},
					skin		=> $story->{primaryskid},
				}, '', $ls_other) if $story->{body_length};
			}

			my @commentcount_link;
			my $thresh = $threshComments[1];  # threshold == 0

			$commentcount_link[1] = linkStory({
				sid		=> $story->{sid},
				tid		=> $story->{tid},
				'link'		=> $story->{commentcount} || 0,
				skin		=> $story->{primaryskid},
				linktop	=> 1
			}, '', $ls_other);

			push @commentcount_link, $thresh, ($story->{commentcount} || 0);
			push @links, getData('comments', { cc => \@commentcount_link });

			if ($story->{primaryskid} != $constants->{mainpage_skid} && $gSkin->{skid} == $constants->{mainpage_skid}) {
				my $skin = $reader->getSkin($story->{primaryskid});
				my $url;

				if ($skin->{rootdir}) {
					$url = $skin->{rootdir} . '/';
				} elsif ($user->{is_anon}) {
					$url = $gSkin->{rootdir} . '/' . $story->{name} . '/';
				} else {
					$url = $gSkin->{rootdir} . '/' . $gSkin->{index_handler} . '?section=' . $skin->{name};
				}
	
				push @links, [ $url, $skin->{hostname} || $skin->{title}, '', 'section'];
			}
	
			if ($user->{seclev} >= 100) {
				push @links, [ "$gSkin->{rootdir}/admin.pl?op=edit&sid=$story->{sid}", getData('edit'), '', 'edit' ];
				my $signed = $reader->hasUserSignedStory($story->{stoid}, $user->{uid});
				unless ($signed) {
					push @links, [ "$gSkin->{rootdir}/admin.pl?op=edit&sid=$story->{sid}", getData('nosign'), '', 'edit' ];
				}
			}

			# I added sid so that you could set up replies from the front page -Brian
			$tmpreturn .= slashDisplay('storylink', {
				links	=> \@links,
				sid	=> $story->{sid},
			}, { Return => 1 });

		}

		$return .= $tmpreturn;
		$dispmodelast = $other->{dispmode};
	}
	$return .= getData("briefarticles_end") if $dispmodelast eq "brief";


	unless ($constants->{index_no_prev_next_day}) {
		my($today, $tomorrow, $yesterday, $week_ago) = getOlderDays($form->{issue});
		$return .= slashDisplay('next_prev_issue', {
			today		=> $today,
			tomorrow	=> $tomorrow,
			yesterday	=> $yesterday,
			week_ago	=> $week_ago,
			linkrel		=> $linkrel,
		}, { Return => 1 });
	}
	# limit number of stories leftover for older stories if desired
	$#$stories = ($gSkin->{older_stories_max} - 1) if
		($gSkin->{older_stories_max} < @$stories)
			&&
		($gSkin->{older_stories_max} > 0);

	return $return;

}

#################################################################
createEnvironment();
main();

1;
