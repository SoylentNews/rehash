package Slash::SearchToo;

use strict;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# FRY: Prepare to be thought at!

#################################################################
sub new {
	my($class, $user, @args) = @_;

	return undef unless $class->isInstalled();

	# We don't instantiate an object of class Slash::SearchToo.
	# Instead, a var determines which API subclass of S::ST the
	# site wants, and an object of that class is created here
	# and returned.
	my $constants = getCurrentStatic();
	my $api_class = $constants->{search_too_class} || 'Slash::SearchToo::Classic';
#	return undef unless $api_class->isInstalled();
	# Just in case this var is set incorrectly, prevent an infinite
	# loop between new and getObject.
	die "var 'search_too_class' invalid" if $api_class eq $class;

	my $self = getObject($api_class, $user, @args);
	if (!$self) {
		warn "Could not get $api_class: $@";
		$self = {};
		# I don't understand why SearchToo *re*blesses this object here -- jamie
		# it doesn't, it only blesses if there is no $self -- pudge
		bless($self, $class);
		$self->{virtual_user} = $user;
		$self->sqlConnect();
	}

	return $self;
}

sub isInstalled {
	my($class) = @_;
	# Slash::SearchToo is subclassed by Slash::SearchToo::Indexer
	# and that's subclassed as well.  But all the subclasses are
	# installed if and only if Slash::SearchToo is.  So override
	# the default check.
	my $constants = getCurrentStatic();
	return $constants->{plugin}{SearchToo};
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
# these are implemeted only in backend modules
sub findRecords  { warn "findRecords must be implemented in a subclass"; return }
# these are OK to be nonfunctional
sub storeRecords { return }
sub addRecords   { return }
sub prepRecord   { return }
sub getRecords   { return }


#################################################################
# take the results and prepare the data for returning
sub prepResults {
	my($self, $results, $records, $sopts) = @_;

	# two ways of calling
	if (ref $sopts eq 'ARRAY') {
		$sopts = {
			total	=> $sopts->[0],
			matches	=> $sopts->[1],
			start	=> $sopts->[2],
			max	=> $sopts->[3]
		};
	}

	### prepare results
	$records ||= [];
	$results->{records_next}     = 0;
	$results->{records_end}      = scalar @$records
		? ($sopts->{start} + @$records - 1)
		: undef;

	if (defined $sopts->{matches}) {
		$results->{records_next} = $results->{records_end} + 1
			if $sopts->{matches} > $results->{records_end} + 1;
	} else {
		# we added one before; subtract it now
		--$sopts->{max};
		if (@$records >= $sopts->{max}) {
			pop @$records;
			$results->{records_next} = $sopts->{start} + $sopts->{max};
			$results->{records_end}  = $results->{records_next} - 1;
		}
	}

	$results->{records}          = $records;
	$results->{records_returned} = scalar @$records;
	$results->{records_total}    = $sopts->{total};
	$results->{records_matches}  = $sopts->{matches};
	$results->{records_max}      = $sopts->{max};
	$results->{records_start}    = $sopts->{start};
	if ($sopts->{matches}) {
		$results->{records_page}  = int($sopts->{start}/$sopts->{max}) + 1;
		$results->{records_pages} = int($sopts->{matches}/$sopts->{max}) + 1;
	} else {
		$results->{records_page}  = $results->{records_page} = 0;
	}

	return $results;
}


#################################################################
# basic processing for common data types
sub _fudge_data {
	my($self, $data) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my %processed;

	my $topic = $data->{tids} || $data->{tid} || $data->{topic};
	if ($topic) {
		my @topics = ref $topic
			? @$topic
			: $topic;
		$processed{topic} = \@topics;

		my @topic_names;
		for my $tid (@topics) {
			next if $tid =~ /\D/;
			my $name = $reader->getTopic($tid, 'keyword');
			push @topic_names, $name if $name;
		}
		$processed{topic_names} = \@topic_names;

	} else {
		$processed{topic} = [];
		$processed{topic_names} = [];
	}


	if ($data->{primaryskid}) {
		$processed{section} = $data->{primaryskid};
	} elsif ($data->{section}) {
		# make sure we pass a skid
		if ($data->{section} =~ /^\d+$/) {
			$processed{section} = $data->{section};
		} else {
			$processed{section_name} = $data->{section};
			# get section name, for most compatibility with this API
			my $skid = $reader->getSkidFromName($data->{section});
			$processed{section} = $skid if $skid;
		}
	}

	if ($processed{section}) {
		my $skin = $reader->getSkin($processed{section});
		if ($skin) {
			$processed{section_name} ||= $skin->{name};
		}
	}


	if ($data->{uid}) {
		$processed{uid_name} = $reader->getUser($data->{uid}, 'nickname');
	}


	if ($data->{date}) {
		my $format = '%Y%m%d%H%M%S';
		$processed{date} = timeCalc($data->{date}, '%Y%m%d%H%M%S');
		$processed{dayssince1970} = int(timeCalc($data->{date}, '%s') / 86400);
	}

	return \%processed;
}


1;

__END__
