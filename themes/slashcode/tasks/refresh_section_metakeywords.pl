#!/usr/bin/perl -w
#
# $Id$
#
# SlashD Task (c) OSDN 2001
#
# Description: refreshes the static "metakeywordsd" template for use
# in HTML output.

use strict;

use Slash::Display;

use vars qw( %task $me );

$task{$me}{timespec} = '47 0-23/6 * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $skins = $slashdb->getSkins;
	my $skin = '';
	my $tmpl = '';
	my %topics_index;
	my $stories_per_skin = 10;
	my $topics_per_skin = 10;

	$tmpl .= "[% SWITCH gSkin.name %]\n";
	foreach my $s (sort keys %$skins) {
		$skin .= " $skins->{$s}{name}";
		my $stories_ref = $slashdb->sqlSelectColArrayref(
			"stoid",
			"stories",
			"time < NOW() AND primaryskid='$s'",
			"ORDER BY time DESC LIMIT $stories_per_skin");

		if (@$stories_ref) {
			my $stoid_str = join ',', @$stories_ref;
			my $tid_ref = $slashdb->sqlSelectColArrayref(
				"tid",
				"story_topics_rendered",
				"stoid IN ($stoid_str)",
				"LIMIT $topics_per_skin",
				{ distinct => 1 }
			);
			if (@$tid_ref){
				my $tid_str = join ',', @$tid_ref;
				my $topic_ref = $slashdb->sqlSelectColArrayref(
					"textname",
					"topics",
					"tid IN ($tid_str)",
					"LIMIT $topics_per_skin",
					{ distinct => 1 }
				);
				$tmpl .= "[% CASE '$skins->{$s}{name}' %]\n";
				$tmpl .= " $skins->{$s}{title} section: stories related to ";
				my $topics_str = join(', ', @$topic_ref);
				$topics_str =~ s/,([^,]*)$/, and$1/;
				$tmpl .= $topics_str.".\n";
				$topics_index{$_}++ for @$topic_ref;
			}
		}
	}

=pod

	# XXXSKIN - i believe mainpage should be taken care of above, but
	# i am not entirely sure that it is taken care of properly, given
	# various weights and all ...
	$tmpl .= "[% CASE 'mainpage' %]\n";
	$tmpl .= " Main page: stories related to ";
	my($topics_count) = sort { $a <=> $b } scalar(keys %topics_index), $topics_per_skin;
	my $topics_str .=  join(', ',
		(sort
			{$topics_index{$b} <=> $topics_index{$a}}
			keys %topics_index
		)[0 .. ($topics_count - 1)]
	);
	$topics_str =~ s/,([^,]*)$/, and$1/;
	$tmpl .= $topics_str.".\n";
=cut

	$tmpl .= "[% END %]\n";

	# If it exists, we update it; if not, we create it
	my $tpid = $slashdb->getTemplateByName('metakeywordsd', {
		values		=> 'tpid',
		ignore_errors	=> 1,
	});

	my %template = (
		name		=> 'metakeywordsd',
		tpid		=> $tpid, 
		template	=> $tmpl,
	);
	if ($tpid) {
		$slashdb->setTemplate($tpid, \%template);
	} else {
		$slashdb->createTemplate(\%template);
	}

	return "skin meta-keywords refreshed: $skin ";
};

1;

