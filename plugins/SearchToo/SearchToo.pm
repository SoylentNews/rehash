package Slash::SearchToo;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################
sub new {
	my($class, $user) = @_;

	my $constants = getCurrentStatic();
	return unless $constants->{plugin}{'SearchToo'};

	my $api_class = $constants->{search_too_class} || 'Slash::SearchToo::Classic';
	# we COULD do a use base here ... but then different Slash sites
	# cannot use different backends, so hang it -- pudge
	my $self = getObject($api_class, $user);

	if (!$self) {
		$self = {};
		bless($self, $class);
		$self->{virtual_user} = $user;
		$self->sqlConnect();
	}

	return $self;
}

#################################################################
# these may be implemeted in backend modules
sub getOps {
	my %ops = (
		comments	=> 1,
		stories		=> 1,
	);
	return \%ops;
}


#################################################################
sub prepResults {
	my($self, $results, $records, $total, $matches, $start, $max) = @_;

	### prepare results
	# undef if we cannot find for sure, or if not applicable
	$records ||= [];
	$results->{records_next}     = 0;
	$results->{records_end}      = scalar @$records
		? ($start + @$records - 1)
		: undef;

	if (defined $matches) {
		$results->{records_next} = $results->{records_end} + 1
			if $matches > $results->{records_end};
	} else {
		# we added one before; subtract it now
		--$max;
		if (@$records >= $max) {
			pop @$records;
			$results->{records_next} = $start + $max;
			$results->{records_end}  = $results->{records_next} - 1;
		}
	}

	$results->{records}          = $records;
	$results->{records_returned} = scalar @$records;
	$results->{records_total}    = $total;
	$results->{records_matches}  = $matches;
	$results->{records_max}      = $max;
	$results->{records_start}    = $start;

	return $results;
}


#################################################################
# these are implemeted in backend modules
sub findRecords {
	return;
}


#################################################################
sub addRecords {
	return;
}
