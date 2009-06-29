# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Slashboxes;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(getUserSlashboxes displaySlashboxes);

#################################################################
sub getUserSlashboxes {
	my $boxes = getCurrentUser('slashboxes');
	$boxes =~ s/'//g;
	return split /,/, $boxes;
}

#################################################################
sub displaySlashboxes {
	my($skin, $older_stories_essentials, $other) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $cache = getCurrentCache();
	my $gSkin = getCurrentSkin();

	return if $user->{noboxes};

	my $return = '';
	my(@boxes, $boxcache);
	my($boxBank, $skinBoxes) = $reader->getPortalsCommon();
	my $getblocks = $skin->{skid} || $constants->{mainpage_skid};

	# two variants of box cache: one for index with portalmap,
	# the other for any other section, or without portalmap

	if ($user->{slashboxes}
		&& ($getblocks == $constants->{mainpage_skid} || $constants->{slashbox_sections})
	) {
		@boxes = getUserSlashboxes();
		$boxcache = $cache->{slashboxes}{index_map}{$user->{light}} ||= {};
	} else {
		@boxes = @{$skinBoxes->{$getblocks}}
			if ref $skinBoxes->{$getblocks};
		$boxcache = $cache->{slashboxes}{$getblocks}{$user->{light}} ||= {};
	}

	my $dynamic_blocks_reader = getObject("Slash::DynamicBlocks");

	for my $bid (@boxes) {
		next if $user->{lowbandwidth}  && $constants->{lowbandwidth_bids_regex} eq "NONE";
		next if $user->{lowbandwidth} && !($bid =~ $constants->{lowbandwidth_bids_regex} );
		if ($bid eq 'mysite') {
			$return .= portalsidebox(
				getData('userboxhead', {}, 'index'),
				$user->{mylinks} || getData('userboxdefault', {}, 'index'),
				$bid,
				'',
				$getblocks
			);

		} elsif ($bid =~ /_more$/ && $older_stories_essentials) {
			$return .= portalsidebox(
				getData('morehead', {}, 'index'),
				getOlderStories($older_stories_essentials, $skin,
					{ first_date => $other->{first_date}, last_date => $other->{last_date} }),
				$bid,
				'',
				$getblocks,
				'olderstuff'
			) if @$older_stories_essentials;

		} elsif ($bid eq 'userlogin' && ! $user->{is_anon}) {
			# do nothing!

		} elsif ($bid eq 'userlogin' && $user->{is_anon}) {
			$return .= $boxcache->{$bid} ||= portalsidebox(
				$boxBank->{$bid}{title},
				slashDisplay('userlogin', { extra_modals => 1 }, { Return => 1, Nocomm => 1 }),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url},
				$getblocks,
				'login'
			);

                } elsif ($bid eq 'index_jobs' && ($user->{is_anon} || !$constants->{use_default_slashboxes})) {
                        # do nothing!
                        
		} elsif ($bid eq 'poll' && !$constants->{poll_cache}) {
			if ($dynamic_blocks_reader) {
				# Poll ad (currently disabled)
				my $poll_supplement = [];
				#$poll_supplement->[0] = { "poll_ad" => '' } if (!$user->{maker_mode_adless} && !$user->{is_subscriber});
				$return .= $dynamic_blocks_reader->displayBlock('poll', {}, $poll_supplement);
			} else {
				# this is only executed if poll is to be dynamic
				$return .= portalsidebox(
					$boxBank->{$bid}{title},
					pollbooth('_currentqid', 1),
					$boxBank->{$bid}{bid},
					$boxBank->{$bid}{url},
					$getblocks
				);
			}
		} elsif ($bid eq 'friends_journal' && $constants->{plugin}{Journal} && $constants->{plugin}{Zoo}) {
			my $journal = getObject("Slash::Journal", { db_type => 'reader' });
			my $zoo = getObject("Slash::Zoo", { db_type => 'reader' });
			my $uids = $zoo->getFriendsUIDs($user->{uid});
			my $articles = $journal->getsByUids($uids, 0,
				$constants->{journal_default_display}, { titles_only => 1 })
				if $uids && @$uids;
			# We only display if the person has friends with data
			if ($articles && @$articles) {
				$return .= portalsidebox(
					getData('friends_journal_head', {}, 'index'),
					slashDisplay('friendsview', { articles => $articles }, { Return => 1, Page => 'index' }),
					$bid,
					"$gSkin->{rootdir}/my/journal/friends",
					$getblocks
				);
			}
		# this could grab from the cache in the future, perhaps ... ?
		} elsif ($bid eq 'rand' || $bid eq 'srandblock') {
			# don't use cached title/bid/url from getPortalsCommon
			my $data = $reader->getBlock($bid, [qw(title block bid url)]);
			$return .= portalsidebox(
				@{$data}{qw(title block bid url)},
				$getblocks
			);

                } elsif ($bid eq 'srandblock_ostg' && !$constants->{use_default_slashboxes}) {
                        # Don't add this Slashbox at all if the site has it toggled off

		} else {
			my $block = '';
			$block = $dynamic_blocks_reader->displayBlock($bid) if $dynamic_blocks_reader;
			if ($block) {
				$return .= $block;
			} else {
				$boxcache->{$bid} ||= portalsidebox(
					$boxBank->{$bid}{title},
					$reader->getBlock($bid, 'block'),
					$boxBank->{$bid}{bid},
					$boxBank->{$bid}{url},
					$getblocks
				);
				$return .= $boxcache->{$bid};
			}
		}
	}

	my $slug = '<div id="slug-%s" class="block nosort slug"><div class="content"></div></div>';
	$return .= sprintf($slug . $slug, 'Crown', 'Top');

	return $return;
}

1;

__END__
