# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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

	# Use trial and error to find a "fallback" font we like.
	# If we want to get fancy, we could do the same with some
	# TTF fonts which could scale, and try to find good point
	# sizes for them too (names of TTF fonts should be stored
	# in a var).
	$self->{imagemargin} = $constants->{hc_q1_maxrad} || 6;

	my @possible_fonts = @{$constants->{hc_possible_fonts}};
	@possible_fonts = ( gdMediumBoldFont, gdLargeFont, gdGiantFont ) if !@possible_fonts;
	@possible_fonts = sort { int(rand(3))-1 } @possible_fonts;

	$self->{prefnumpixels} = $constants->{hc_q1_prefnumpixels} || 1000;
	my $gdtext = new GD::Text();
	$gdtext->font_path($constants->{hc_fontpath} || '/usr/share/fonts/truetype');
	$gdtext->set_text($self->shortRandText());
	my $smallest_diff = 2**31;
	for my $font (@possible_fonts) {
		@{$self->{set_font_args}} = ( $font );
		if ($font =~ m{^(\w+)/(\d+)$}) {
			@{$self->{set_font_args}} = ($1, $2);
		}
		$gdtext->set_font(@{$self->{set_font_args}});
		my($tempw, $temph) = ($gdtext->get("width"), $gdtext->get("height"));
		my $pixels = ($tempw+$self->{imagemargin}) * ($temph+$self->{imagemargin});
		my $diff = $pixels - $self->{prefnumpixels};
		$diff = -$diff if $diff < 0;
		if ($diff < $smallest_diff) {
			$self->{font} = $font;
			$smallest_diff = $diff;
		}
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
	my $secs = $constants->{hc_pool_secs_before_del} || 21600;
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
			 AND inuse = 0
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
			my $filename = $pool_hr->{$hcpid}{filename};
			my $fullname = catfile($filedir, $filename);
			my $errstr = "";
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
			my $new_delrows = $self->sqlDelete(
				"humanconf_pool",
				"hcpid IN ($hcpids_list)"
			);
			if ($new_delrows != $remaining_to_delete) {
				warn "HumanConf warning: deleted number"
					. " of rows '$new_delrows'"
					. " not equal to attempted number to delete"
					. " '$remaining_to_delete'";
			}
			$remaining_to_delete -= $new_delrows;
			$delrows += $new_delrows;
		} else {
			warn "HumanConf warning: no rows to delete; attempted"
				. " '$remaining_to_delete'";
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
	my $answer;
	my $extension;
	my $retval;

	if ($question == 1) {
		$extension = ".jpg";
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
		$filename = sprintf("%02d/%s$extension", $hcpid%100, $encoded_name);
		$full_filename = "$dir/$filename";
		if (-e $full_filename) {
			$filename = "";
			$randomfactor = rand(1000);
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
			print $fh $retval->jpeg;
			close $fh;
		}
		my($width, $height) = $retval->getBounds();
		if ($width*$height < $self->{prefnumpixels}/1.5) {
			# Display small images at larger sizes for easier reading.
			my $scale = int($self->{prefnumpixels}/($width*$height) + 0.5);
			$scale = 3 if $scale > 3;
			$width *= $scale; $height *= $scale;
		}
		$html = join("",
			qq{<img src="},
			$self->{questioncache}{$question}{urlprefix},
			"/",
			$filename,
			qq{" width=$width height=$height border=0 },
			qq{alt="random letters - if you are visually impaired, please email us at }
				. fixparam($constants->{adminmail})
				. qq{">}
		);
	}

	$self->sqlUpdate("humanconf_pool", {
		filename =>	$filename,
		html =>		$html,
		inuse =>	0,
		-created_at =>	'NOW()',
	}, "hcpid=$hcpid");
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
	my $gdtext = new GD::Text();
	$gdtext->font_path($constants->{hc_fontpath} || '/usr/share/fonts/truetype');

	# Set up the text, and set up the image.
	my $answer = shortRandText();
	$gdtext->set_text($answer);
	$gdtext->set_font(@{$self->{set_font_args}});
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

	my $poly = new GD::Polygon;
	if ($width+$height > 100) {
		# Draw a grid of lines on the image, same color as the text.
		my $pixels_between = ($width+$height)/8;
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

	# Superimpose the text over the random stuff.
	my $gdtextalign = new GD::Text::Align(
		$image,
		halign=>"center", valign=>"center",
		color => $textcolor
	);
	$gdtextalign->set(text => $gdtext->get("text"));
	$gdtextalign->set_font($gdtext->get("font") , $gdtext->get("ptsize"));
	my $max_angle = $constants->{hc_q1_maxrad} || 0.2;
	my $angle = (rand(1)*2-1) * $max_angle;
	$gdtextalign->draw(int($width/2), int($height/2), $angle);

	return($answer, $image);
}

sub shortRandText {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $num_chars = $constants->{hc_q1_numchars} || 3;
	my @c = ('a'..'g', 'i'..'k',
		# Noel, Noel
		# (we don't use letters that could be confused
		# with numbers or other letters)
		'm', 'n', 'p'..'t', 'v'..'z');
	my $text = "";
	while (!$text) {
		for (1..$num_chars) {
			$text .= $c[rand(@c)];
		}
	}
	$text;
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

