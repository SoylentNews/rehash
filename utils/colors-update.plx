#!/usr/bin/perl -w
# updates Slash pre-T_2_3_0_53 to the new colors
# AFTER running the updates in sql/mysql/upgrades run this
#
#  perl colors-update.plx VIRTUAL_USER
#
# do not run more than once

use Slash::Test shift;

my @color_bids = sort keys %{$slashdb->getDescriptions("color_block")};
for my $bid (@color_bids) {
	my @c = split ",", $slashdb->getBlock($bid)->{block};
	my @f = @c[0..$#c/2];
	my @b = @c[$#c/2+1..$#c];
	splice(@f, 5, 0, $f[2]);
	splice(@b, 5, 0, $f[3]);
	$slashdb->setBlock($bid, { block => join(",", @f, @b) });
	print "$bid\t@f @b\n"
}

__END__
