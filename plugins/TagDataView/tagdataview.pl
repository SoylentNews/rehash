#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use warnings;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use GD::Graph::lines;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();

	if (!$user->{is_admin}) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	my %ops = (
		default		=> [ 1, \&show,		1000,	0 ],
		fhpopgraph	=> [ 1, \&fhpopgraph, 	1000,	1 ],
	);

	my $op = $form->{op} || 'default';

	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED] || $user->{seclev} < $ops{$op}[MINSECLEV]) {
                redirect("$gSkin->{rootdir}/");
                return;
	}

	# column [3] is true if this op emits an image
	if (!$ops{$op}[3]) {
		my $ok = header('TagDataView', '');
		if (!$ok) { print STDERR "ok='$ok'\n"; }
		return unless $ok;
	}
	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $gSkin);
	if (!$ops{$op}[3]) {
		footer();
	}
}

sub show {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $tag_count = load_tag_count();
	my $nonneg = load_nonneg();
	slashDisplay('display', {
		remarks =>	'',
		tag_count =>	$tag_count,
		nonneg =>	$nonneg,
		cur_hour =>	int(time/3600)*3600,
	});
}

sub load_tag_count {
	my $tagdv_r = getObject('Slash::TagDataView', { db_type => 'reader' });
	my %tag_count = (
		tags => {	hour	=>  $tagdv_r->getUniqueTagCount('tags',     3600),
				hour_fh	=>  $tagdv_r->getUniqueTagCount('tags',     3600, { only_firehose => 1 }),
				day	=>  $tagdv_r->getUniqueTagCount('tags',    86400),
				day_fh	=>  $tagdv_r->getUniqueTagCount('tags',    86400, { only_firehose => 1 }),
				week	=>  $tagdv_r->getUniqueTagCount('tags',  7*86400),
				week_fh	=>  $tagdv_r->getUniqueTagCount('tags',  7*86400, { only_firehose => 1 }),
#				month	=>  $tagdv_r->getUniqueTagCount('tags', 30*86400),
#				month_fh => $tagdv_r->getUniqueTagCount('tags', 30*86400, { only_firehose => 1 }),
		},
		users => {	hour	=>  $tagdv_r->getUniqueTagCount('users',     3600),
				hour_fh	=>  $tagdv_r->getUniqueTagCount('users',     3600, { only_firehose => 1 }),
				day	=>  $tagdv_r->getUniqueTagCount('users',    86400),
				day_fh	=>  $tagdv_r->getUniqueTagCount('users',    86400, { only_firehose => 1 }),
				week	=>  $tagdv_r->getUniqueTagCount('users',  7*86400),
				week_fh	=>  $tagdv_r->getUniqueTagCount('users',  7*86400, { only_firehose => 1 }),
#				month	=>  $tagdv_r->getUniqueTagCount('users', 30*86400),
#				month_fh => $tagdv_r->getUniqueTagCount('users', 30*86400, { only_firehose => 1 }),
		},
		objects => {	hour	=>  $tagdv_r->getUniqueTagCount('objects',     3600),
				hour_fh	=>  $tagdv_r->getUniqueTagCount('objects',     3600, { only_firehose => 1 }),
				day	=>  $tagdv_r->getUniqueTagCount('objects',    86400),
				day_fh	=>  $tagdv_r->getUniqueTagCount('objects',    86400, { only_firehose => 1 }),
				week	=>  $tagdv_r->getUniqueTagCount('objects',  7*86400),
				week_fh	=>  $tagdv_r->getUniqueTagCount('objects',  7*86400, { only_firehose => 1 }),
#				month	=>  $tagdv_r->getUniqueTagCount('objects', 30*86400),
#				month_fh => $tagdv_r->getUniqueTagCount('objects', 30*86400, { only_firehose => 1 }),
		},
		votes => {	hour	=>  $tagdv_r->getUniqueTagCount('votes',     3600),
				hour_fh	=>  $tagdv_r->getUniqueTagCount('votes',     3600, { only_firehose => 1 }),
				day	=>  $tagdv_r->getUniqueTagCount('votes',    86400),
				day_fh	=>  $tagdv_r->getUniqueTagCount('votes',    86400, { only_firehose => 1 }),
				week	=>  $tagdv_r->getUniqueTagCount('votes',  7*86400),
				week_fh	=>  $tagdv_r->getUniqueTagCount('votes',  7*86400, { only_firehose => 1 }),
#				month	=>  $tagdv_r->getUniqueTagCount('votes', 30*86400),
#				month_fh => $tagdv_r->getUniqueTagCount('votes', 30*86400, { only_firehose => 1 }),
		},
	);
	for my $tk (qw( hour day week )) {
		for my $type (grep !/_fh$/, keys %tag_count) {
			my $num = $tag_count{$type}{"${tk}_fh"}	|| 0;
			my $denom = $tag_count{$type}{$tk}	|| 0;
			my $p = '-';
			$p = sprintf("%.3g", $num*100/$denom) if $denom;
			$tag_count{$type}{"${tk}_fh_perc"} = $p;
		}
	}
	return \%tag_count;
}

sub load_nonneg {
	my $tagdv_r = getObject('Slash::TagDataView', { db_type => 'reader' });
	my %nonneg = (
		hour => $tagdv_r->getMostNonnegativeTaggedGlobjs({ lookback_secs =>    3600 }),
		day  => $tagdv_r->getMostNonnegativeTaggedGlobjs({ lookback_secs =>   86400 }),
		week => $tagdv_r->getMostNonnegativeTaggedGlobjs({ lookback_secs => 7*86400 }),
	);
	return \%nonneg;
}

sub fhpopgraph {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $tdv = getObject('Slash::TagDataView');

	my $start_time = $form->{start_time} || (int(time/3600)*3600 - 86400);
	$start_time =~ /^(\d+)$/; $start_time = $1;
	my $start_sql = $tdv->sqlSelect("FROM_UNIXTIME($start_time)");

	my $end_time = $form->{end_time} || int(time/3600)*3600;
	$end_time =~ /^(\d+)$/; $end_time = $1;
	my $end_sql = $tdv->sqlSelect("FROM_UNIXTIME($end_time)");

	my $duration = $form->{duration} || 12 * 3600;
	$duration =~ /^(\d+)$/; $duration = $1;

	my $form_y_ceil = 0;
	$form_y_ceil = $1 if $form->{y_ceil} && $form->{y_ceil} =~ /^(\d+)$/;

	my $width = $form->{width} || 600;	$width =~ /^(\d+)$/;  $width = $1;
	my $height = $form->{height} || 480;	$height =~ /^(\d+)$/; $height = $1;

	emit_image_header('image/png');

	my $mcd = $slashdb->getMCD();
	my $mcdkey = undef;
	if ($mcd) {
		my $params = join "_",
			$start_time, $end_time, $duration, $form_y_ceil, $width, $height;
		$mcdkey = "$slashdb->{_mcd_keyprefix}:tdvfhpg:$params";
		my $value = $mcd->get($mcdkey);
		if ($value) {
			print $value;
			return;
		}
	}

	my $y_max = 0;

	my $g_hr = $tdv->sqlSelectAllHashref(
		[qw( globjid secsin )],
		'firehose.globjid, secsin, userpop, firehose.popularity',
		'firehose, firehose_history',
		"firehose.globjid=firehose_history.globjid
		 AND createtime BETWEEN '$start_sql' AND '$end_sql'
		 AND secsin <= '$duration'");
	my %globjids = ( map { ($_, 1) } keys %$g_hr );
	my @globjids = sort { $a <=> $b } keys %globjids;
	my %finalpop = ( map { ($_, $g_hr->{$_}{0}{popularity}) } @globjids );

	my $min_incr = 5;
	my $keep_repeats = 6;
	my %color_map = ( stories => 'orange', submissions => 'blue', journals => 'lgreen', urls => 'lpurple' );
	my @colors = ( );
	my @line_types = ( );
	my @data = ( );
	for my $globjid (@globjids) {
		my($type, $target_id) = $tdv->getGlobjTarget($globjid);
		push @line_types, 1; # 1 = solid
		push @colors, $color_map{$type} || 'gray';
		my $globjid_pop_ar = [ ];
		my $last_v = undef;
		my $repeats = 0;
		my @secsin = sort { $a <=> $b } keys %{$g_hr->{$globjid}};
		for my $secsin (@secsin) {
			my $v = $g_hr->{$globjid}{$secsin}{userpop};
			push @$globjid_pop_ar, $v;
			$y_max = $v if $v > $y_max;
			if (defined($last_v) && $last_v == $v) {
				++$repeats;
			} else {
				$repeats = 0;
			}
			$last_v = $v;
		}
		if ($repeats > $keep_repeats && $last_v == $g_hr->{$globjid}{0}{popularity}) {
			my $n_undef = $repeats - $keep_repeats;
			for my $j (-$n_undef .. -1) {
				$globjid_pop_ar->[$j] = undef;
			}
		}
		push @data, $globjid_pop_ar;
	}

	my $secsin_count = scalar @{$data[0]};

	# Add the lower bound threshold for each color level
	my $firehose = getObject('Slash::FireHose');
	my @roygbiv = qw( red orange yellow green blue purple dpurple );
	for my $i (1..@roygbiv) {
		my $colorname = $roygbiv[$i-1];
		my $min = $firehose->getMinPopularityForColorLevel($i);
#		unshift @line_types, 2; # 2 = dashed, 3 = dotted
		unshift @line_types, 3; # 2 = dashed, 3 = dotted
		unshift @colors, $colorname;
		unshift @data, [ ($min) x $secsin_count ];
	}

	# Add the x axis
	unshift @line_types, 1;
	unshift @data, [ ];
	my $incr_mult = $min_incr;
	while ($secsin_count*$min_incr/$incr_mult >= 30) {
		$incr_mult *= 2;
	}
	for my $i (0..$secsin_count-1) {
		my $mins = $min_incr*$i;
		if ($mins % $incr_mult == 0) {
			push @{$data[0]}, sprintf("%.2g", $mins/60);
		} else {
			push @{$data[0]}, '';
		}
	}

	my $n_items = scalar keys %$g_hr;
	my $graph = GD::Graph::lines->new($width, $height);
	my $y_ceil = $form_y_ceil || (int($y_max/40)+1) * 40;
	$graph->set(
		x_label =>		'Hours after creation',
		y_label =>		'popularity',
		title =>		"$n_items firehose globjs created $start_sql to $end_sql",
		x_min_value =>		0,
		x_label_skip =>		int(30 / $min_incr),
		y_min_value =>		-40,
		y_max_value =>		$y_ceil,
		y_tick_number =>	($y_ceil+40) / 40,
		skip_undef =>		1,
		dclrs =>		\@colors,
		line_types =>		\@line_types,
	) or warn $graph->error;

#use Data::Dumper;
#print STDERR "colors: " . Dumper(\@colors);
#print STDERR "data: " . Dumper(\@data);
	my $gd = $graph->plot(\@data) or warn $graph->error;
	my $png = $gd ? $gd->png : undef;
	print $png if $png;
	if ($png && $mcd) {
		$mcd->set($mcdkey, $png, 3600);
	}

}

sub emit_image_header {
	my($content_type) = @_;
	my $r = Apache->request;
	$r->content_type($content_type);
	# the "private" may be optional, but should do what we want
	$r->header_out('Cache-Control', 'private');
	$r->send_http_header;
}

createEnvironment();
main();

1;

