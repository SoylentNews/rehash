# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::HumanConf::Static;

use strict;
use Digest::MD5;
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
	$self->{imagemargin} = 6;
	my @possible_fonts = ( gdMediumBoldFont, gdLargeFont, gdGiantFont );
	$self->{prefnumpixels} = $constants->{hc_q1_prefnumpixels} || 1000;
	my $gdtext = new GD::Text();
	$gdtext->font_path($constants->{hc_fontpath} || '/usr/share/fonts/truetype');
	$gdtext->set_text($self->shortRandText());
	my $smallest_diff = 2**31;
	for my $font (@possible_fonts) {
		$gdtext->set_font(font => $font);
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
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $max_fill = $constants->{hc_poolmaxfill} || 100;

	my $cursize = $self->getPoolSize();
	my $max_delete = int(($cursize-100)/2);
	return 0 if $max_delete <= 0;
	$max_delete = $max_fill if $max_delete > $max_fill;

	# THIS DOES NOT YET DELETE THE FILES, ONLY THE DATABASE ROWS!!!

	return $self->sqlDelete(
		"humanconf_pool",
		"lastused < DATE_SUB(NOW(), INTERVAL 2 DAY)",
		$max_delete
	);
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
		warn "addPool called with unknown question number: $question";
	}

	# As long as filename is empty, this row won't be used.  We
	# need to insert it first, to get its hcpid which decides
	# what the filename will be.
	my $success = $self->sqlInsert("humanconf_pool", {
		hcqid =>	$question,
		answer =>	$answer,
		filename =>	"",
		html =>		"",
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
		if (!open(my $fh, ">$full_filename")) {
			warn "addPool could not create '$full_filename', $!";
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
			qq{alt="(random letters)">}
		);
	}

	$self->sqlUpdate("humanconf_pool", {
		filename =>	$filename,
		html =>		$html,
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
	$gdtext->set_font( font => $self->{font} );
	my($width, $height) = ($gdtext->get("width")+$self->{imagemargin},
		$gdtext->get("height")+$self->{imagemargin});
	my $image = new GD::Image($width, $height);

	# Set up the image's colors.
	my $background = $image->colorAllocate(255, 255, 255);
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
	my $offblack = int(rand(10));
	my $textcolor = $image->colorAllocate($offblack, $offblack, $offblack);
	my $n_dotcolors = 10;
	my @dotcolor = ( );
	for (1..$n_dotcolors) {
		push @dotcolor, $image->colorAllocate(
			int(255-rand(64)),
			int(255-rand(64)),
			int(255-rand(64)),
		);
	}

	# Paint the white background.
	$image->filledRectangle(0, 0, $width, $height, $background);

	# Draw a light-colored random polygon on the image.
	my $poly = new GD::Polygon;
	my $n_vertices = int(rand(2)+3);
	for (1..$n_vertices) {
		$poly->addPt(int(rand($width)), int(rand($height)));
	}
	$image->polygon($poly, $polycolor);

	# Speckle with random dots (number proportional to the size of
	# the image).
	my $n_dots = $width*$height/40;
	$n_dots += rand($n_dots/3);
	$n_dots -= rand($n_dots*2/3);
	for (1..int($n_dots)) {
		my($x, $y) = (int(rand($width)), int(rand($height)));
		$image->setPixel($x, $y, @dotcolor[rand($n_dotcolors)]);
	}

	# Superimpose the text over the random stuff.
	my $gdtextalign = new GD::Text::Align(
		$image,
		halign=>"center", valign=>"center",
		color => $textcolor
	);
	$gdtextalign->set(text => $gdtext->get("text"));
	$gdtextalign->set_font($gdtext->get("font") , $gdtext->get("ptsize"));
	$gdtextalign->draw(int($width/2), int($height/2), 0);

	return($answer, $image);
}

sub shortRandText {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $num_chars = $constants->{hc_q1_numchars} || 3;
	my @c = ('a'..'k',
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
			warn "writeBlankIndexes could not create $file, $!";
		} else {
			print $fh "<html><body>fnord</body></html>";
			close $fh;
		}
	}
}


