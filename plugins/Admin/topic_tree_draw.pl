#!/usr/bin/perl -w

# $Id$

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/5 * * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, we can wait
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $reader = getObject("Slash::DB", { db_type => "reader" });

	if (!$constants->{topic_tree_draw}) {
		return "topic_tree_draw not set";
	}

	my $lc = $slashdb->getVar('topic_tree_lastchange', 'value', 1) || 0;
	my $ld = $slashdb->getVar('topic_tree_lastdraw', 'value', 1) || 0;
	if ($lc < $ld) {
		return "no change";
	}

	my $ok;
	eval {
		$ok = require GraphViz;
	};
	if ($@ || $! || !$ok) {
		my $msg = "GraphViz not available, exiting";
		# Don't throw a serious error here.  If the admin doesn't
		# want to install GraphViz that's fine, it's not required.
		# slashdErrnote($msg);
		return $msg;
	}

	my $fontname = $constants->{topic_tree_draw_fontname} || 'freefont/FreeMono';
	my $fontsize = $constants->{topic_tree_draw_fontsize} || 10;
	my $g = GraphViz->new(
		concentrate => 1,		# edge merging for clarity
		epsilon => 0.001,		# try real hard to reduce clutter
		rankdir => 1,			# horizontal layout
		node =>	{ fontname => $fontname, fontsize => $fontsize },
		edge =>	{ fontname => $fontname, fontsize => $fontsize,
			  dir => "back" },
	);
	return "could not initialize GraphViz object, aborting" unless $g;

	# Set up random colors for arrows.
	srand(1);
	my @hsv = ( );
	for my $h (0..16) {
		for my $s (7..8) {
			for my $v (4..8) {
				push @hsv, sprintf("%0.4f,%0.4f,%0.4f", $h/16, $s/8, $v/8)
			}
		}
	}
	@hsv = sort { int(rand(3))-1 } @hsv;

	my $new_lastdraw = time;
	my $tree = $slashdb->getTopicTree('', { no_cache => 1 });
	my $mpt = $constants->{mainpage_nexus_tid} || 1;

	# Tell GraphViz what it needs to know.
	my @tids_to_draw =
		sort { $a <=> $b }
		grep { $_ < 10000 }
		keys %$tree;
	for my $tid (@tids_to_draw) {
		my $topic = $tree->{$tid};
		my $color;
		if ($tid == $mpt) {
			$color = "cyan";
		} else {
			$color = $topic->{nexus} ? "yellow" : "white";
		}
		my $shape = $topic->{nexus} ? "box" : "ellipse";
		my $count = $reader->countStoriesWithTopic($tid) || 0;
		$g->add_node($tid,
			label => "$topic->{textname}\n$tid\n$count",
			fillcolor => $color,
			style => "filled",
			shape => $shape,
		);
		my @children_to_include =
			sort { $a <=> $b }
			grep { $_ < 10000 }
			@{$topic->{children}};
		for my $ctid ( @children_to_include ) {
			$g->add_edge($tid, $ctid,
				style => $topic->{child}{$ctid} >= 30 ? "dashed" : "solid",
				color => $hsv[ ($tid+$ctid) % @hsv ],
			);
		}
	}

	# Get the PNG from GraphViz.
	my $png_data = $g->as_png;

	# Write it to disk.
	my $filename = "$constants->{basedir}/images/topic_tree.png";
	if (open(my $fh, ">$filename")) {
		print $fh $png_data;
		close $fh;
	} else {
		my $msg = "could not write to '$filename', $!";
#		slashdErrnote($msg);
		return $msg;
	}

	# Update the lastdraw var.  If it hasn't been created, create it.
	# (It really should have been created, but if it wasn't, and we
	# didn't, then we'd redraw the PNG every time this task was
	# called, which would be quite a waste.)
	if ($ld == 0) {
		$slashdb->createVar("topic_tree_lastdraw", $new_lastdraw, 'Unix timestamp of last time topic_tree_draw.pl redrew images/topic_tree.png');
	} else {
		$slashdb->setVar("topic_tree_lastdraw", $new_lastdraw);
	}

	return "drew new tree";
};

1;
