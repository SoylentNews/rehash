#!/srv/soylentnews.org/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

require bytes;
use strict;
use utf8;
use Encode;

use Slash::Constants qw(:slashd :messages);
use Slash::Display;
use Slash::Utility;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 2:00 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '0 0 1 1 *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

# this used to call dailyStuff; now it is just in a task
#	system("$constants->{sbindir}/dailyStuff $virtual_user &");
	my $messages  = getObject('Slash::Messages');
	generateUUCPBatch($constants, $slashdb);

	return;
};

sub generateUUCPBatch {
	my($constants, $slashdb) = @_;
	my $gSkin = getCurrentSkin();

	# First we need to spool out the articles, this is relatively easy
	my $story_data = $slashdb->getArticlesForUUCPBatch();
	return unless @$story_data;

	my $absolutedir = $gSkin->{absolutedir};

	my $batch_file = "/tmp/uucp_batch";

	# Needed to get UTF-8 to write properly
	binmode(STDOUT, ":utf8");
	open (my $file_handle, '>', $batch_file);

	for (@$story_data) {
		my(%story, @ref);
		@story{qw(sid title section author tid time dept
			introtext bodytext discussion)} = @$_;

		1 while chomp($story{introtext});
		1 while chomp($story{bodytext});

		$story{introtext} = parseSlashizedLinks($story{introtext});
		$story{bodytext} =  parseSlashizedLinks($story{bodytext});
		$story{msg_id} = "<story-$story{sid}\@soylentnews.org>";
		my $asciitext = $story{introtext};
		$asciitext .= "\n\n" . $story{bodytext};
		($story{asciitext}, @ref) = html2text($asciitext, 74);

		$story{refs} = \@ref;

		my $batch;
		$batch = slashDisplay("netnews_story",
			{ story => \%story, urlize => \&daily_urlize, absolutedir => $absolutedir },
			{ Return => 1, Nocomm => 1, Page => 'nntp', Skin => 'NONE' }
		);

		# Hack to get newlines after each entry
		$batch .= "\n";

		# Now determine the size in bytes for the rnews header
		my $header = "#! rnews " . bytes::length($batch);
		print $file_handle $header . "\n" . $batch;

		# Now get comments for this story
		my $comments = $slashdb->getCommentsByDiscussionForUUCPBatch($story{discussion});
		for (@$comments) {
			my (%comment, @ref);
			@comment{qw(nickname cid date subject pid comment)} = @$_;

			1 while chomp($comment{comment});
			$comment{comment} = parseSlashizedLinks($comment{comment});
			$comment{msg_id} = "<comment-$comment{cid}!story-$story{sid}\@soylentnews.org>";
			$asciitext = $comment{comment};

			($comment{asciitext}, @ref) = html2text($asciitext, 74);
			$comment{refs} = \@ref;

			# Need to determine what the references field should be, if pid == 0
			# then it needs to point at the story, else at the comment listed
			if ($comment{pid} == 0) {
				$comment{reference} = "<story-$story{sid}\@soylentnews.org>";
			} else {
				$comment{reference} = "<comment-$comment{pid}!story-$story{sid}\@soylentnews.org>";
			}

			# FIXME: we should calculate this in the template, not here
			$comment{ref_count} = scalar @ref - 1; #subtract 1 so if the array is empty its zero
			print $comment{ref_count};
			$batch = slashDisplay("netnews_comment",
				{ comment => \%comment, urlize => \&daily_urlize, absolutedir => $absolutedir },
				{ Return => 1, Nocomm => 1, Page => 'nntp', Skin => 'NONE' }
			);

			# Hack to get newlines after each entry
			$batch .= "\n";

			# Now determine the size in bytes for the rnews header
			my $header = "#! rnews " . bytes::length($batch);
			print $file_handle $header . "\n" . $batch;
		}
	}

	# let everything write out
	close $file_handle;
	return 0;
}

sub daily_urlize {
	local($_) = @_;
	s/^(.{62})/$1\n/g;
	s/(\S{74})/$1\n/g;
	$_ = "<URL:" . $_ . ">";
	return $_;
}

1;
