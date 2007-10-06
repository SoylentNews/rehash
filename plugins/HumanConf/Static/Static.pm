# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::HumanConf::Static;

use strict;
use Digest::MD5;
use File::Spec::Functions;
use GD;
use GD::Text::Align;
use Slash;
use Slash::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{HumanConf};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	$self->{imagemargin} = $constants->{hc_q1_margin} || 6;

	# Set the list of possible fonts.
	if ($constants->{hc_possible_fonts} && @{$constants->{hc_possible_fonts}}) {
		@{ $self->{possible_fonts} } = @{$constants->{hc_possible_fonts}};
	} else {
		@{ $self->{possible_fonts} } = ( gdMediumBoldFont, gdLargeFont, gdGiantFont );
	}

	return $self;
}

sub getPoolSize {
	my($self) = @_;
	return $self->sqlCount("humanconf_pool");
}

sub deleteOldFromPool {
	my($self, $want_delete_fraction) = @_;
	my $constants = getCurrentStatic();
	my $max_fill = $constants->{hc_poolmaxfill} || 100;

	my $cursize = $self->getPoolSize();
	if (!defined($want_delete_fraction)) {
		# Delete at least enough to recycle the pool regularly.
		# Since by default hc_maintain_pool runs 2 times an hour,
		# the default fraction is enough to guarantee complete
		# pool turnover every day.
		# Note that $runs_per_hour should be coordinated with
		# the timespec in the task .pl file;  there isn't a good
		# way to do this at the moment.  Eventually we'll have
		# DB-based timespecs and we can read that...
		my $runs_per_hour = 2;
		$want_delete_fraction = 1/($runs_per_hour*24)
	}
	my $want_delete = int($cursize*$want_delete_fraction);
		# Don't delete so many that the pool will get too empty,
		# or take too long to fill.
	my $max_delete_check = int(($cursize-100)/2);
	return 0 if $max_delete_check <= 0;
	$max_delete_check = $want_delete * 10 if $max_delete_check > $want_delete*10;
	$max_delete_check = $max_fill if $max_delete_check > $max_fill;
		# How many we actually want to delete can't be more
		# than the maximum we're allowed to delete.
	$want_delete = $max_delete_check if $want_delete > $max_delete_check;

	my $min_hcpid = $self->sqlSelect("MIN(hcpid)", "humanconf_pool");
	my $max_hcpid = $self->sqlSelect("MAX(hcpid)", "humanconf_pool");

	# Five passes.  First, mark the ones we're going to delete.
	# (We pick ones that are both old and haven't been used recently,
	# two separate things.)  Second, pick which of those we want to
	# delete.  Third, delete their files from disk.  Fourth, delete
	# their rows.  Fifth, of the ones we didn't delete, mark them as
	# available for use again.  Do this several times until we get
	# enough deleted to make a difference.
	
	my $delrows = 0;
	my $loop_num = 1;
	my $remaining_to_delete = $want_delete;
	my $successfully_deleted = 0;
	my $secs = $constants->{hc_pool_secs_before_del} || 21600;
	my $lastused_max_secs = $secs * 2;
	$lastused_max_secs = 86400*3 if $lastused_max_secs < 86400*3;
	my $q_hr = $self->sqlSelectAllHashref(
		"hcqid",
		"hcqid, filedir",
		"humanconf_questions"
	);
	while ($loop_num <= 4 && $remaining_to_delete > 0) {

		# Pass 1:
		# "inuse=2" means it's marked for deletion.  The interval
		# is a stopgap to prevent us from a cycle of frantic
		# creating/deleting (which otherwise could happen with
		# bizarre values of $want_delete_fraction).
		my $hcpid_clause = $min_hcpid
			+ $max_delete_check * ($loop_num*3+1);
		if ($hcpid_clause >= $max_hcpid) {
			$hcpid_clause = "";
		} else {
			$hcpid_clause = "AND hcpid <= $hcpid_clause";
		}
		my $rows = $self->sqlUpdate(
			"humanconf_pool",
			{ inuse => 2, -lastused => "lastused" },
			"lastused < DATE_SUB(NOW(), INTERVAL $secs SECOND) 
			 AND (inuse = 0 OR lastused < DATE_SUB(NOW(), INTERVAL $lastused_max_secs SECOND))
			 $hcpid_clause"
		);
		next if !$rows;

		# Pass 2:
		# Pull out a certain number of the ones we just marked, and get
		# their info.
		my $pool_hr = $self->sqlSelectAllHashref(
			"hcpid",
			"hcpid, hcqid, filename",
			"humanconf_pool",
			"inuse=2",
			"ORDER BY hcpid ASC LIMIT $want_delete"
		);

		# Pass 3:
		# Delete the files of the ones we just pulled out.
		my @hcpids = sort { $a <=> $b } keys %$pool_hr;
		# Make sure we don't delete too many.
		my @hcpids_to_delete = @hcpids;
		if (scalar(@hcpids_to_delete) > $remaining_to_delete) {
			$#hcpids_to_delete = $remaining_to_delete-1;
		}
		my @row_ids_to_delete = ( );
		for my $hcpid (@hcpids_to_delete) {
			my $filedir = $q_hr->{$pool_hr->{$hcpid}{hcqid}}{filedir};
			my $errstr = "";
			my $filename = $pool_hr->{$hcpid}{filename};
			$errstr = "filename is empty for hcpid '$hcpid'"
				if !$filename;
			my $fullname = catfile($filedir, $filename);
			$errstr = "file '$fullname' does not exist"
				if !-e $fullname;
			$errstr = "parent dir of '$fullname' not writable"
				if !-w $filedir;
			if (!$errstr) {
				my $success = unlink $fullname;
				if (!$success) {
					# Could not delete this file, but
					# we know it's there.  That's bad.
					$errstr = "unlink '$fullname' failed, $!";
				}
			}
			# Whether the attempt to delete the file succeeded
			# or not, we're going to delete this row.
			push @row_ids_to_delete, $hcpid;
			warn "HumanConf warning on id '$hcpid': $errstr" if $errstr;
		}

		# Pass 4:
		# Delete the rows of the ones whose files we deleted.
		if (@row_ids_to_delete) {
			my $hcpids_list = join(",", @row_ids_to_delete);
			my $new_delrows = $self->sqlDelete('humanconf_pool', "hcpid IN ($hcpids_list)");
			$self->sqlDelete('humanconf', "hcpid IN ($hcpids_list)");
			$successfully_deleted += $new_delrows;
			$remaining_to_delete -= $new_delrows;
			$delrows += $new_delrows;
		}

		# Pass 5:
		# Anything still marked for deletion has been spared...
		# this time.
		$self->sqlUpdate(
			"humanconf_pool",
			{ inuse => 0, -lastused => "lastused" },
			"inuse = 2"
		);

		++$loop_num;
	}

	if ($loop_num > 2) {
		warn scalar(gmtime) . " hc_maintain_pool.pl deleteOldFromPool looped $loop_num times, deleted $successfully_deleted of $want_delete";
	}
	
	# Return the number of rows successfully deleted.  This
	# should also be the number of files deleted.
	return $delrows;
}

sub fillPool {
	my($self) = @_;
	my $constants = getCurrentStatic();

	my $cursize = $self->getPoolSize();
	my $wantedsize = $constants->{hc_poolsize} || 10000;
	my $max_fill = $constants->{hc_poolmaxfill} || 100;
	my $needmore = $wantedsize - $cursize;
	return if $needmore <= 0;
	$needmore = $max_fill if $needmore > $max_fill;

	$self->{questioncache} = $self->sqlSelectAllHashref(
		"hcqid",
		"hcqid, filedir, urlprefix",
		"humanconf_questions"
	);

	for (1..$needmore) {
		$self->addPool(1); # always question 1, for now
	}
	return $needmore;
}

sub addPool {
	my($self, $question) = @_;
	my($answer, $extension, $method, $retval);
	my $image_format = getCurrentStatic('hc_image_format') || 'jpeg';
	$image_format =~ s/\W+//g;

	if ($question == 1) {
		if ($image_format =~ /^jpe?g$/) {
			$extension = '.jpg';
			$method = 'jpeg';
		} else {
			$extension = ".$image_format";
			$method = $image_format;
		}
		($answer, $retval) = $self->drawImage();
	} else {
		warn "HumanConf warning: addPool called with"
			. " unknown question number: $question";
	}

	# As long as filename is empty, this row won't be used.  We
	# need to insert it first, to get its hcpid which decides
	# what the filename will be.
	my $success = $self->sqlInsert("humanconf_pool", {
		hcqid =>	$question,
		answer =>	$answer,
		filename =>	"",
		html =>		"",
		inuse =>	1,
	});
	my $hcpid = $self->getLastInsertId();
	my $dir = $self->{questioncache}{$question}{filedir};

	my($filename, $full_filename) = ('', '');
	my $randomfactor = 0;
	while (!$filename) {
		# Loop until we get a filename that isn't already used.
		# (Collisions should only occur one time in a zillion, but
		# it's always a good idea to check.)
		my $encoded_name = $self->encode_hcpid($hcpid + $randomfactor);
		$filename = sprintf("%02d/%s%s", $hcpid % 100, $encoded_name, $extension);
		$full_filename = "$dir/$filename";
		if (-e $full_filename) {
			$filename = "";
			$randomfactor = int(rand(1000));
		}
	}
	my $full_dir = $full_filename;
	$full_dir =~ s{/[^/]+$}{};
	my @created_dirs = File::Path::mkpath($full_dir, 0, 0755);
	$self->writeBlankIndexes(@created_dirs) if @created_dirs;

	my $html = "";
	if ($question == 1) {
		my $constants = getCurrentStatic();
		if (!open(my $fh, ">$full_filename")) {
			warn "HumanConf warning: addPool could not create"
				. " '$full_filename', '$!'";
		} else {
			print $fh $retval->$method;
			close $fh;
		}
		my($width, $height) = $retval->getBounds();
		if ($width*$height < $self->{prefnumpixels}/1.5) {
			# Display small images at larger sizes for easier reading.
			my $scale = int($self->{prefnumpixels}/($width*$height) + 0.5);
			$scale = 3 if $scale > 3;
			$width *= $scale; $height *= $scale;
		}
		my $alt = getData('imgalttext', {}, 'humanconf');
		$html = join("",
			qq{<img src="},
			$self->{questioncache}{$question}{urlprefix},
			"/",
			$filename,
			qq{" width=$width height=$height border=0 },
			qq{alt="$alt">}
		);
	}

	$self->sqlUpdate("humanconf_pool", {
		filename =>	$filename,
		html =>		$html,
		inuse =>	0,
		-created_at =>	'NOW()',
	}, "hcpid=$hcpid");
}

sub get_sizediff {
	my($self, $gdtext, $pixels_wanted, $font, $fontsize) = @_;
	$gdtext->set_font($font, $fontsize) or die("g_s gdt->set_font('$font', '$fontsize') failed: " . $gdtext->error);
	my($tempw, $temph) = ($gdtext->get("width"), $gdtext->get("height"));
	my $pixels = ($tempw+$self->{imagemargin}) * ($temph+$self->{imagemargin});
	my $diff = abs($pixels - $pixels_wanted);
	return $diff;
}

sub get_new_gdtext {
	my($self, $text) = @_;
	my $constants = getCurrentStatic();

	my $gdtext = new GD::Text();
	$gdtext->font_path($constants->{hc_fontpath} || '/usr/share/fonts/truetype');
	$gdtext->set_text($text);

	return $gdtext;
}

sub get_font_args {
	my($self, $text) = @_;
	my $constants = getCurrentStatic();

	my $gdtext = $self->get_new_gdtext($text);

	$self->{prefnumpixels} = $constants->{hc_q1_prefnumpixels} || 1000;

	my @pf = @{ $self->{possible_fonts} };
	my $font = @pf[rand @pf] || '';
	my $first_fontsize_try = 30; # default first guess
	if ( $font =~ m{^(\w+)/(\d+)$} ) {
		$font = $1;
		$first_fontsize_try = $2;
	}

	# "pixels wanted"
	my $pw = $self->{prefnumpixels};

	# We are looking for the minimum of the pixel difference.  Since
	# image size increases monotonically with font size, there is
	# guaranteed to be exactly 1 or 2 values at which the pixel diff
	# is at a minimum.  We begin with one guess, then check the
	# diffs immediately above and below it to see which is headed in
	# the right direction.
	my $i = $first_fontsize_try - 1;
	my $j = $first_fontsize_try; # first guess
	my $k = $first_fontsize_try + 1;
	my $di = $self->get_sizediff($gdtext, $pw, $font, $i);
	my $dj = $self->get_sizediff($gdtext, $pw, $font, $j);
	my $dk = $self->get_sizediff($gdtext, $pw, $font, $k);
	if ($di == $dj || $dj == $dk) {
		# Two values being equal means that they are both the
		# minimum, so we can return either one.  We got lucky!
		return ($font, $j);
	}
	if ($di > $dj && $dj < $dk) {
		# The center value being smaller than the other two
		# means that it is the one minimum.  We got lucky!
		return ($font, $j);
	}

	# Either i or k is a better choice than j.  Figure out which,
	# then set up the vars so we walk up or down sizes starting
	# from there.
	my @vals = ( $j );
	my $start = $j;
	my $multiplier;
	if ($di < $dj) {
		# i is a better direction, so we walk down.
		$multiplier = 5/6;
		push @vals, $i;
	} else {
		# k is a better direction, so we walk up.
		$multiplier = 6/5;
		push @vals, $k;
	}

	# Walk up or down until we bridge the minimum.  We'll know
	# that happens when we find a value that _increases_ from
	# the minimum seen so far.  We want to save the last 3
	# values found, at that point.
	my $min_so_far = $dj;
	my $best_size = $j;
	my $found_min = 0;
	my $next_try = $start;
	my($fontsize_smallest, $fontsize_largest) = (5, 100);
	while (!$found_min) {
		my $old_try = $next_try;
		$next_try = int($old_try * $multiplier + 0.5);
		if ($next_try == $old_try) {
			# Must change by at least one point size
			if ($multiplier < 1) {
				$next_try = $old_try - 1;
			} else {
				$next_try = $old_try + 1;
			}
		}
		push @vals, $next_try;
		my $new_d = $self->get_sizediff($gdtext, $pw, $font, $next_try);
		if ($new_d < $min_so_far) {
			# That beats the old record.
			$min_so_far = $new_d;
			$best_size = $next_try;
		} else {
			# OK, we've crossed the minimum and come back up.
			$found_min = 1;
		}
		if ($next_try < $fontsize_smallest || $next_try > $fontsize_largest) {
			# We're out of bounds, that's bad.
			$found_min = 1;
			print STDERR scalar(gmtime) . " Font size out of bounds: $font $next_try $new_d\n";
		}
	}

	# The answer we want is somewhere in the range of the last
	# 3 values we checked.
	my($left, $right);
	if ($multiplier < 1) {
		$left = $vals[-1];
		$right = $vals[-3];
	} else {
		$left = $vals[-3];
		$right = $vals[-1];
	}
#print STDERR "font=$font left=$left right=$right vals=@vals\n";

	# Hopefully this is a narrow range so we can just check values
	# within it to find the answer we want.  (This could be better
	# optimized, but at this point, image generation happens very
	# quickly, so I'm satisfied so far.)
	$min_so_far = 2**31 - 1;
	$best_size = undef;
	DO_TRY: for $next_try ($left .. $right) {
		my $new_d = $self->get_sizediff($gdtext, $pw, $font, $next_try);
		if ($new_d < $min_so_far) {
			$min_so_far = $new_d;
			$best_size = $next_try;
		} else {
#print STDERR "font=$font next_try=$next_try new_d=$new_d min_so_far=$min_so_far done\n";
			# We've just gone past the minimum, we're done.
			last DO_TRY;
		}
#print STDERR "font=$font next_try=$next_try new_d=$new_d min_so_far=$min_so_far best_size=$best_size\n";
	}

	return($font, $best_size);
}

sub drawImage {
	my($self) = @_;
	my $constants = getCurrentStatic();

	# The idea is to get the number of bits of randomness, excluding
	# the answer text, up at least around the number of images in the
	# pool (probably 10K or more).  If fewer bits, then a dedicated
	# attacker could break the pool in better than brute force and
	# our pool is too large and wasting resources.	The below code
	# has about 140 bits of randomness by my count, which is almost
	# certainly more than the RNG, so the bottleneck here is the
	# number of bits in the RNG seed, so we should easily be safe.

	# Set up the text object (this could probably be cached in $self,
	# but it hardly takes any time to do it over and over).
	my $answer = $self->shortRandText();
	my @font_args = $self->get_font_args($answer);
	my $gdtext = $self->get_new_gdtext($answer);
	$gdtext->set_font(@font_args) or die("dI gdt->set_font('@font_args') failed: " . $gdtext->error);

	# Based on the font size for this word, and the resulting size
	# of the drawn text, set up the image object.
	my($width, $height) = ($gdtext->get("width")+$self->{imagemargin},
		$gdtext->get("height")+$self->{imagemargin});
	my $image = new GD::Image($width, $height);

	# Set up the image's colors.
	my $background = $image->colorAllocate(255, 255, 255);
	my $offblack = int(rand(10));
	my $textcolor = $image->colorAllocate($offblack, $offblack, $offblack);

	my $n_dotcolors = 10;
	my @dotcolor = ( );
	for (1..$n_dotcolors) {
		push @dotcolor, $image->colorAllocate(
			int(255-rand(192)),
			int(255-rand(192)),
			int(255-rand(192)),
		);
	}

	# Paint the white background.
	$image->filledRectangle(0, 0, $width, $height, $background);

	if ($image->can('setThickness')) {
		# I don't think GD prior to 2.07 has setThickness().
		$image->setThickness($constants->{hc_q1_linethick} || 1);
	}
	my $poly = new GD::Polygon;
	if ($width+$height > 100) {
		# Draw a grid of lines on the image, same color as the text.
		my $lc = $constants->{hc_q1_linecloseness} || 8;
		my $pixels_between = ($width+$height)/$lc;
		$pixels_between = 20 if $pixels_between < 20;
		my $offset = int(rand($pixels_between));
		my $x = int(rand($pixels_between));
		while ($x < $width) {
			$poly->addPt($x, 0);
			$poly->addPt($x+$offset, $height-1) if $x+$offset < $width;
			$x += $pixels_between;
		}
		my $y = int(rand($pixels_between));
		while ($y < $width) {
			$poly->addPt(0, $y);
			$poly->addPt($width-1, $y+$offset) if $y+$offset < $height;
			$y += $pixels_between;
		}
		$image->polygon($poly, $textcolor);
	} else {
		# And now some fancy footwork to pick a light, "pastel"ish,
		# reasonably saturated color.
		my $hue_rand = 160;
		my @pc = ( 255-int(rand($hue_rand)) );
		$hue_rand -= 255-$pc[0];
		push @pc, 255-int(rand($hue_rand));
		@pc = reverse @pc if rand(1) < 0.5;
		if (rand(1) < 1/3)	{ unshift @pc, 255 }
		elsif (rand(1) < 0.5)	{ @pc = ( $pc[0], 255, $pc[1] ) }
		else			{ push @pc, 255 }
		my $polycolor = $image->colorAllocate(@pc);
		# Draw a light-colored random polygon on the image.
		my $n_vertices = int(rand(2)+3);
		for (1..$n_vertices) {
			$poly->addPt(int(rand($width)), int(rand($height)));
		}
		$image->polygon($poly, $polycolor);
	}

	# Speckle with random dots (number proportional to the size of
	# the image).
	my $n_dots = $width*$height/40;
	$n_dots += rand($n_dots/3);
	$n_dots -= rand($n_dots*2/3);
	for (1..int($n_dots)) {
		my($px, $py) = (int(rand($width)), int(rand($height)));
		$image->setPixel($px, $py, @dotcolor[rand($n_dotcolors)]);
	}

	# Set up an alignment box so we can determine where to put the
	# text on the image.
	my $gdtextalign_bbox = new GD::Text::Align(
		$image,
		halign => 'center', valign => 'center',
		text   => $answer,
	);
	$gdtextalign_bbox->set_font(@font_args) or die("gdta_b->set_font('@font_args') failed: " . $gdtextalign_bbox->error);
	my($center_x, $center_y) = (int($width/2), int($height/2));
	# Pick an angle between $max_angle/4 and $max_angle, randomly
	# positive or negative.
	my $max_angle = $constants->{hc_q1_maxrad} || 0.2;
	my $angle = (rand(1)*0.75)*$max_angle + $max_angle/4;
	$angle *= -1 if rand(1) < 0.5;
	# The variable names stand for lower left x coordinate, etc.
	my($ll_x, $ll_y, $lr_x, $lr_y, $ur_x, $ur_y, $ul_x, $ul_y) =
		$gdtextalign_bbox->bounding_box($center_x, $center_y, 0);
#print STDERR "aligned $answer center=$center_x, $center_y angle=$angle bb: $ll_x, $ll_y, $lr_x, $lr_y, $ur_x, $ur_y, $ul_x, $ul_y\n";

	# We're done with the alignment box now.  Place the text on the
	# image according to the bounding box.  Split the string into a
	# left and right half and draw them separately.
	my $string_break = int(rand(length($answer)-2))+1;
	my $answer_left = substr($answer, 0, $string_break);
	my $angle_left = $angle;
	my $gdtextalign_left = new GD::Text::Align(
		$image,
		halign => 'left', valign => 'center',
		colour => $textcolor, # apparently Australians prefer a 'u'
		text   => $answer_left,
	);
	$gdtextalign_left->set_font(@font_args) or die("gdta_l->set_font('@font_args') failed: " . $gdtextalign_left->error);
	my $cl_y = int(($ll_y+$ul_y)/2);
	my @bb = $gdtextalign_left->draw(int($ul_x), $cl_y, $angle);
#printf STDERR "gdta_left drew left-top $answer_left at ul_x=$ul_x,cl_y=$cl_y angle=%.4f, bb: @bb\n", $angle;
	my $answer_right = substr($answer, $string_break);
	my $angle_right = rand(1) < 0.5 ? $angle : -$angle;
	my $gdtextalign_right = new GD::Text::Align(
		$image,
		halign => 'right', valign => 'center',
		colour => $textcolor, # apparently Australians prefer a 'u'
		text   => $answer_right,
	);
	$gdtextalign_right->set_font(@font_args) or die("gdta_r->set_font('@font_args') failed: " . $gdtextalign_right->error);
	my $cr_y = int(($lr_y+$ur_y)/2);
	@bb = $gdtextalign_right->draw(int($lr_x), $cr_y, $angle_right);
#printf STDERR "gdta_right drew right-bottom $answer_right at lr_x=$lr_x,cr_y$cr_y angle=%.4f, bb: @bb\n", $angle;

	return($answer, $image);
}

sub shortRandText {
	my($self) = @_;
	my $constants = getCurrentStatic();

	my $text = "";
	if ($constants->{hc_q1_usedict} && $constants->{hc_q1_numchars} > 2) {
		$text = $self->shortRandText_dict();
	}
	return $text if $text;

	my $omit = $constants->{hc_q1_lettersomit} || 'hlou';
	my $omit_regex = qr{[^$omit]};
	my $num_chars = $constants->{hc_q1_numchars} || 3;
	my @c = grep /$omit_regex/, ('a' .. 'z');
	while (!$text) {
		for (1..$num_chars) {
			$text .= $c[rand(@c)];
		}
	}
	return $text;
}

sub shortRandText_dict {
	my $constants = getCurrentStatic();
	my $filename = $constants->{hc_q1_usedict};
	return "" if !$filename || !-r $filename;
	my $options = {
		min_chars	=> $constants->{hc_q1_numchars} - 1,
		max_chars	=> $constants->{hc_q1_numchars} + 1,
		excl_regexes	=> [ split / /, ($constants->{hc_q1_usedict_excl} || "") ],
	};
	$options->{min_chars} = 3 if $options->{min_chars} < 3;
	return getRandomWordFromDictFile($filename, $options);
}

# To prevent attackers from pulling down all the images and manually
# typing up a correlation of filename to text, we randomize the
# images' filenames.
sub encode_hcpid {
	my($self, $hcpid) = @_;
	my $constants = getCurrentStatic();
	my $randchars = "";
	for (1..10) {
		$randchars .= sprintf("%c", rand(253)+1);
	}
	my $md5 = Digest::MD5::md5_hex("$randchars$hcpid");
	return substr($md5, 10, 12);
}

# We must also make sure attackers can't just websurf to the directory
# holding a bunch of images and get Apache to deliver them the list
# (or randomizing the filenames would serve no purpose).
sub writeBlankIndexes {
	my($self, @dirs) = @_;
	for my $dir (@dirs) {
		my $file = "$dir/index.shtml";
		next if -e $file;
		if (!open(my $fh, ">$file")) {
			warn "HumanConf warning: writeBlankIndexes"
				. " could not create $file, $!";
		} else {
			print $fh "<html><body>fnord</body></html>";
			close $fh;
		}
	}
}

1;
