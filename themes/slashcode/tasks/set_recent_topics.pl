#!/usr/bin/perl -w

# This task (and its associated templates and other changes)
# was rewritten almost in its entirety, by Shane Zatezalo
# <shane at lottadot dot com>, May 2002.

use strict;
use File::Spec;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '1-59/15 * * * *';
$task{$me}{timespec_panic_1} = ''; # not important
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $ar = $slashdb->getNewStoryTopic();
	my($html, $num_stories, $cur_tid) = ('', 0);
	my $block = '';
	my $topics = $slashdb->getDescriptions('topics');
	my %tid_list = ( );
	while (my $cur_story = shift @$ar) {
		my $cur_tid = $cur_story->{tid};
		# We only want unique topics to be shown.
		next if exists $tid_list{$cur_story->{tid}};
		$tid_list{$cur_story->{tid}}++;
		++$num_stories;
		if ($num_stories <= $constants->{recent_topic_img_count}) {
			if ($cur_story->{image} =~ /^\w+\.\w+$/) {
				$cur_story->{image} = join("/",
					$constants->{imagedir},
					"topics",
					$cur_story->{image}
				);
			}
			$html .= slashDisplay('setrectop_img', {
				id	=> $cur_tid,
				image	=> $cur_story->{image},
				width	=> $cur_story->{width},
				height	=> $cur_story->{height},
				alttext	=> $cur_story->{alttext},
			}, 1);
		}
		if ($num_stories <= $constants->{recent_topic_txt_count}) {
			$block .= slashDisplay('setrectop_txt', {
				id	=> $cur_tid,
				name	=> $topics->{$cur_tid},
			}, 1);
		}
		if ($num_stories >= $constants->{recent_topic_img_count}
			&& $num_stories >= $constants->{recent_topic_txt_count}) {
			# We're done, no more are needed.
			last;
		}
	}
	my($tpid) = $slashdb->getTemplateByName('recentTopics', 'tpid');
	$slashdb->setTemplate($tpid, { template => $html });
	$slashdb->setBlock('recenttopics', {
		block =>	$block,
		bid =>		'recenttopics', 
	});
	return ;
};

1;

