#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '1-59/15 * * * *';
$task{$me}{timespec_panic_1} = ''; # not important
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $sth = $slashdb->getNewStoryTopic();
	my ($html, $num_stories, $cur_tid) = ('', 0);

	my(%tid_list);
	while (my $cur_story = $sth->fetchrow_hashref) {
		my $cur_tid = $cur_story->{tid};
		# We only want unique topics to be shown.
		next if exists $tid_list{$cur_story->{tid}};
		$tid_list{$cur_story->{tid}}++;
		if ($cur_story->{image} =~ /^\w+\.\w+$/) {
			$cur_story->{image} =
			"$constants->{imagedir}/topics/$cur_story->{image}";
		}

# This really shoud be in a template.
		$html .= <<EOT;
	<TD><A HREF="$constants->{rootdir}/search.pl?topic=$cur_tid"><IMG
		SRC="$cur_story->{image}"
		WIDTH="$cur_story->{width}" HEIGHT="$cur_story->{height}"
		BORDER="0" ALT="$cur_story->{alttext}"></A>
	</TD>
EOT

		# 5 == Var?
		last if ++$num_stories >= 5;
	}
	$sth->finish();
	my($tpid) = $slashdb->getTemplateByName('recentTopics', 'tpid');
	$slashdb->setTemplate($tpid, { template => $html });

	return ;
};

1;

