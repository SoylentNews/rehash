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
	my $sections = $slashdb->getSections();
	my $sect = "";
	my $tmpl = "";
	my %topics_index;
	my $stories_per_section = 10;
	my $topics_per_section = 10;
	$tmpl .= "[% SWITCH user.currentSection %]\n";
	foreach my $s (sort keys %$sections) {
		$sect .= " $s";
		my $stories_ref = $slashdb->sqlSelectColArrayref(
			"sid",
			"stories",
			"time < NOW() AND section='$s'",
			"ORDER BY time DESC LIMIT $stories_per_section");
		if (@$stories_ref) {
			my $sid_str = join ',', map{$_="'$_'"} @$stories_ref;
			my $tid_ref = $slashdb->sqlSelectColArrayref(
				"tid",
				"story_topics",
				"sid IN ($sid_str)",
				"LIMIT $topics_per_section",
				{ distinct => 1 } );
			if (@$tid_ref){
				my $tid_str = join ',', @$tid_ref;
				my $topic_ref = $slashdb->sqlSelectColArrayref(
					"alttext",
					"topics",
					"tid IN ($tid_str)",
					"LIMIT $topics_per_section",
					{ distinct => 1 } );
				$tmpl .= "[% CASE '$s' %]\n";
				$tmpl .= " $sections->{$s}->{title} section: stories related to "; 	
				my $topics_str = join(', ', @$topic_ref);	
				$topics_str =~ s/,([^,]*)$/, and$1/;
				$tmpl .= $topics_str.".\n";
				$topics_index{$_}++ for @$topic_ref;
			} 
		}       
	}
	$tmpl .= "[% CASE 'index' %]\n";
	$tmpl .= " Main page: stories related to ";
	my $topics_str .=  join(', ',
			(sort
				{$topics_index{$b} <=> $topics_index{$a}}
				keys %topics_index
			)[0..($topics_per_section-1)]
		);
	$topics_str =~ s/,([^,]*)$/, and$1/;
	$tmpl .= $topics_str.".\n";
	$tmpl .= "[% END %]\n";

	# If it exists, we update it, if not, we create it.  The final "1" arg
	# means to ignore errors.
	my $tpid = $slashdb->getTemplateByName(
		'metakeywordsd', 'tpid', 0, '', '', 1
	);

	my(%template) = ( 
		name => 'metakeywordsd',
		tpid => $tpid, 
		template => $tmpl,
	);
	if ($tpid) {
		$slashdb->setTemplate($tpid, \%template);
	} else {
		$slashdb->createTemplate(\%template);
	}

	return "section meta-keywords refreshed: $sect ";
};

1;

