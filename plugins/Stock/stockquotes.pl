#!/usr/bin/perl -w

use strict;
use Slash;
use Date::Format;
use Finance::Quote;

use vars qw( %task $me );

$task{$me}{timespec} = '50 12-22 * * mon-fri';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (!$task{$me}{table}) {
		# Initialize long-lived variables if we haven't already.
		$task{$me}{table} = $slashdb->sqlSelectAllHashref(
			"name",
			"*",
			"stocks"
		);
		$task{$me}{fq} = Finance::Quote->new;
		my $currency = $task{$me}{table}{currency} || 'USD';
		$task{$me}{fq}->set_currency($currency);
	}
	my $fq = $task{$me}{fq};
	my $table = $task{$me}{table};

	# Generate the easy stuff first.

	my $timeformat = $table->{timeformat}{symbol} || '%R %Z';
	my $last_update = Date::Format::time2str($timeformat,
		time, 'GMT');

	# Now have Finance::Quote retrieve its data, and put everything
	# in the formats we want into the $stocks arrayref.

	my $stocks = [ ];
	for my $stock_key (
		sort { $table->{$a}{stockorder} <=> $table->{$b}{stockorder}
			|| $a cmp $b }
		grep { $table->{$_}{exchange} !~ /^_/ }
		keys %$table
	) {
		my $stock = $table->{$stock_key};
		my($exch, $sym) = ($stock->{exchange}, $stock->{symbol});
		my %stockfetch = $fq->fetch($exch, $sym);
		if (!%stockfetch) {
			slashdLog("failed stockfetch for '$stock_key' '$exch' '$sym'")
				if verbosity() >= 2;
			next;
		}
		$stock->{last}		= sprintf( "%.2f", $stockfetch{$sym,"last"});
		$stock->{net}		= sprintf("%+.2f", $stockfetch{$sym,"net"});
		$stock->{p_change}	= sprintf("%+.2f", $stockfetch{$sym,"p_change"});
		$stock->{year_range}	= $stockfetch{$sym,"year_range"};
		if ($stock->{year_range} =~ /^\s*([\d.]+)\D+([\d.]+)/) {
			$stock->{year_lo}	= sprintf("%.1f", $1);
			$stock->{year_hi}	= sprintf("%.1f", $2);
		}
		if ($stockfetch{$sym,"cap"} ne ""
			and $stockfetch{$sym,"cap"} =~ /([\d.]+)([KMB])?/) {
			$stock->{cap}		= sprintf("%.0f$2", $1);
		} else {
			$stock->{cap}		= "<i>n/a</i>";
		}
		# Remaining keys go in too, as long as they don't step on
		# what has already been set up.
		for my $key (keys %stockfetch) {
			$stock->{$key} = $stockfetch{$key}
				unless defined($stock->{$key});
		}
		push @$stocks, $stock;
	}

	# Process the template.
	my $html = slashDisplay(
		'stockquotes',
		{	stocks		=> $stocks,
			last_update	=> $last_update },
		1);

	if ($html) {
		$slashdb->setBlock('stockquotes', {block => $html});
		$slashdb->setVar('writestatus', 'dirty');
	}

	return ;
};

1;

