package Slash::SearchToo::Classic;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use base 'Slash::DB::Utility';
use base 'Slash::SearchToo';

our $VERSION = $Slash::Constants::VERSION;

# FRY: I did it!  And it's all thanks to the books at my local library.

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Search'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################
sub getOps {
	my %ops = (
		stories		=> 1,
		comments	=> 1,
		journals	=> 1,
		polls		=> 1,
		users		=> 1,
		submissions	=> 1,
		test		=> \&testSearch,
	);
	return \%ops;
}

#################################################################
sub findRecords {
	my($self, $type, $query, $opts) = @_;

	my(%processed);
	my $results = {};
	my $records = [];

	my $constants = getCurrentStatic();
	my $oldsearch = getObject('Slash::Search', { db_type => 'search' });


	### set up common query terms
	my %terms = (
		query	=> $query->{query},
	);

	if ($query->{topic}) {
		my @topics = ref $query->{topic}
			? @{$query->{topic}}
			: $query->{topic};
		$processed{tid} = $topics[0] if @topics;
		# API is expecting multiple args in _multi, so we fake it
		$processed{_multi}{tid} = \@topics if @topics > 1;
	}

	if ($query->{section}) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		# get section name, for most compatibility with this API
		my $skin = $reader->getSkin($query->{section});
		$processed{section} = $skin->{name} if $skin && $skin->{name};
	}

	for (qw(uid author submitter)) {
		$processed{$_} = $query->{$_} if $query->{$_} && $query->{$_} =~ /^\d+$/;
	}


	### set up common options
	# old API cannot tell us total or matches
	# undef if we cannot find for sure, or if not applicable
	my $total	= undef;
	my $matches	= undef;
	my $start	= $opts->{records_start} || 0;
	my $max		= $opts->{records_max}   || $constants->{search_default_display};
	# if we are not getting total number of matches, fetch an extra so we
	# know if there are more, for pagination purposes
	$max++ if !defined $matches;

	# sort can be an arrayref, but old API can handle only one
	my $sort  = ref $opts->{sort} ? $opts->{sort}[0] : $opts->{sort};
	$sort = ($opts->{sort} eq 'date'      || $opts->{sort} eq 1) ? 1 :
		($opts->{sort} eq 'relevance' || $opts->{sort} eq 2) ? 2 :
		0;

### options not used in this backend
#	date_start => '', date_end => '',	


	### dispatch to different queries
	if ($type eq 'stories') {
		for (qw(tid _multi section author submitter)) {
			$terms{$_} = $processed{$_} if $processed{$_};
		}

		$records = $oldsearch->findStory(\%terms, $start, $max, $sort);
	}

	elsif ($type eq 'comments') {
		for (qw(section)) {
			$terms{$_} = $processed{$_} if $processed{$_};
		}
		%terms = (%terms,
			sid		=> $query->{sid},
			threshold	=> $query->{points_min},
		);

		$records = $oldsearch->findComments(\%terms, $start, $max, $sort);
	}

	elsif ($type eq 'journals') {
		for (qw(tid uid)) {
			$terms{$_} = $processed{$_} if $processed{$_};
		}

		$records = $oldsearch->findJournalEntry(\%terms, $start, $max, $sort);
	}

	elsif ($type eq 'polls') {
		for (qw(tid section uid)) {
			$terms{$_} = $processed{$_} if $processed{$_};
		}

		$records = $oldsearch->findPollQuestion(\%terms, $start, $max, $sort);
	}

	elsif ($type eq 'users') {
		# sigh, why is this ONE method passing info in an additional parameter?
		$records = $oldsearch->findUsers(\%terms, $start, $max, $sort, $query->{journal_only});
	}

	elsif ($type eq 'submissions') {
		for (qw(tid section uid)) {
			$terms{$_} = $processed{$_} if $processed{$_};
		}
		%terms = (%terms,
			note		=> $query->{note},
		);

		$records = $oldsearch->findSubmission(\%terms, $start, $max, $sort);
	}

	$self->prepResults($results, $records, [$total, $matches, $start, $max]);
	return $results;
}

#################################################################
# this is a way of adding extra search thingys; we could call another
# search method (as defaultSearch calls findRecords), or just make this our
# search method.
sub testSearch {
	my($reader, $constants, $user, $form, $gSkin, $searchDB, $rss, $query, $opts) = @_;

	my $results	= {};
	my $records	= ['a' .. 'z'];
	my $total	= 26;
	my $matches	= 26;
	my $start	= $opts->{records_start} || 0;
	my $max		= $opts->{records_max} || 26;

	$records = [ @{$records}[$start .. ($start + $max)] ];
	$searchDB->prepResults($results, $records, [$total, $matches, $start, $max]);

	my %return;
	$return{results}   = $results;
	$return{noresults} = 'No results';
	$return{template}  = \ <<EOT;
[% FOREACH letter=results.records %]
<p>[% letter %]</p>
[% END %]
[% PROCESS pagination %]
<p>
EOT

	$return{rss} = {} if $rss;

	return \%return;
}

1;

__END__
