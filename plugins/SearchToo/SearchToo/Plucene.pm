package Slash::SearchToo::Plucene;

# STILL IN PROGRESS NOT READY FOR USE

use strict;
use File::Spec::Functions;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';
use base 'Slash::SearchToo';
use base 'Slash::SearchToo::Classic';

# maybe add our own analyzer ...
use Plucene::Analysis::Standard::StandardAnalyzer;
use Plucene::Document;
use Plucene::Document::DateSerializer;
use Plucene::Index::Writer;
use Plucene::QueryParser;
use Plucene::Search::HitCollector;
use Plucene::Search::IndexSearcher;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: I did it!  And it's all thanks to the books at my local library.

our $handled = qr{^(?:comments)$};

#################################################################
# fields that will be combined into the content field,
# for indexing and tokenization
our %content = (
	comments	=> [qw(comment subject)],
	stories		=> [qw(introtext bodytext title)],
);

# additional fields that will be indexed and tokenized
our %text = (
	comments	=> [ qw(tids) ],
	stories		=> [ qw(tids) ],
);

# fields that will be stored, but not indexed
# (not planning on storing unindexed data for now, so not used)
our %stored = ();

our %primary = (
	comments	=> 'cid',
);

# content fields don't need to be indexed (just in case we do keep them around)
for my $type (keys %stored) {
	unshift @{$stored{$type}}, @{$content{$type}};
}

# turn into hashes
for my $hash (\%text, \%stored) {
	for my $type (keys %$hash) {
		$hash->{$type} = { map { ($_ => 1) } @{$hash->{$type}} };
	}
}

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
	);
	return \%ops;
}

#################################################################
sub findRecords {
	my($self, $type, $query, $opts) = @_;

	# let Classic handle for now
	return Slash::SearchToo::Classic::findRecords(@_) unless $type =~ $handled;
	$self->_type($type);

	my $constants = getCurrentStatic();

	my $processed = _fudge_data($query);
	my $results = {};
	my $records = [];

	### set up common query terms
	my %terms = (
		query	=> $query->{query},
	);


	### set up common options
	my $total	= 0;
	my $matches	= 0;
	my $start	= $opts->{records_start} || 0;
	my $max		= $opts->{records_max}   || $constants->{search_default_display};

	# sort can be an arrayref, but stick with one for now
	## no way to sort by date yet
	my $sort  = ref $opts->{sort} ? $opts->{sort}[0] : $opts->{sort};
	$sort = ($opts->{sort} eq 'date'      || $opts->{sort} eq 1) ? 1 :
		($opts->{sort} eq 'relevance' || $opts->{sort} eq 2) ? 2 :
		0;

	### dispatch to different queries
	if ($type eq 'comments') {
		for (qw(section)) {
			$terms{$_} = $processed->{$_} if $processed->{$_};
		}
		%terms = (%terms,
			sid		=> $query->{sid},
			points_min	=> $query->{points_min},
		);

	}

# deal with ranges for threshold, date ... ?
# how to return results sorted by date?
# remove croaks from QueryParser->parse

	my $parser = Plucene::QueryParser->new({
		analyzer => Plucene::Analysis::Standard::StandardAnalyzer->new(),
		default  => "content" # Default field for non-specified queries
	});
	(my $querystring = $terms{query}) =~ s/([-+&|!{}[\]:\\])~*?/\\$1/g; # allowed: ()"^
	my $newquery = $parser->parse('+(' . $querystring . ')');

	my $filter = 0;
	if (length $terms{points_min}) {
		# fall through if it's exact
		if ($terms{points_min} != $constants->{comment_maxscore}) {
			$filter = Slash::SearchToo::Plucene::Filter->new({
				field => '_points_',
				from  => _get_points(delete $terms{points_min}),
				to    => _get_points($constants->{comment_maxscore}),
			});
		} else {
			$terms{_points_} = _get_points(delete $terms{points_min});
		}
	}

	for my $key (keys %terms) {
		next if $key eq 'query' || ! length($terms{$key});
		my $term = Plucene::Index::Term->new({
			field	=> $key,
			text	=> $terms{$key}
		}) or next;
		my $term_query = Plucene::Search::TermQuery->new({ term => $term }) or next;
		$newquery->add($term_query, 1);
	}

#use Data::Dumper;
#print STDERR Dumper $newquery;
print STDERR $newquery->to_string, "\n";

	my $searcher = $self->_searcher;
	my $docs = $searcher->search_top($newquery, $filter, $start + $max);

	$total   = $searcher->max_doc;
	$matches = $docs->total_hits;

	my $skip = $start;
	for my $obj (sort { $b->{score} <=> $a->{score} } $docs->score_docs) {
		if ($skip > 0) {
			$skip--;
			next;
		}

		last if @$records >= $max;

		my($doc, $score) = @{$obj}{qw(doc score)};
		my $docobj = $searcher->doc($doc);
		my %data   = ( score => $score );

		for my $field ($docobj->fields) {
			my $name = $field->name;
			next if $name =~ /^(?:content|id)$/;
			$data{$name} = $field->string;
		}

		push @$records, \%data;
	}

	$self->getRecords($type => $records);
	$self->prepResults($results, $records, $total, $matches, $start, $max);

	return $results;
}

#################################################################
sub addRecords {
	my($self, $type, $data, $opts) = @_;

	return unless $type =~ $handled;
	$self->_type($type);

	my $constants = getCurrentStatic();

	$data = [ $data ] unless ref $data eq 'ARRAY';

	my @documents;

	for my $record (@$data) {
		next unless keys %$record;
		my $processed = _fudge_data($record);
		my %document;

		if ($type eq 'comments') {
			%document = (
				cid			=> $record->{cid},

				_date_			=> _get_date($record->{date}),
				_points_		=> _get_points($record->{points}),

				comment			=> $record->{comment},
				subject			=> $record->{subject},
				sid			=> $record->{discussion_id},
				primaryskid		=> $processed->{section},
				tids			=> join(' ', @{$processed->{topic}}),
			);
		}

		push @documents, \%document;
	}

	my $preader = $self->_reader;
	for my $document (@documents) {
		# delete if it is already in there
		my $term = Plucene::Index::Term->new({
			field	=> $primary{$type},
			text	=> $document->{ $primary{$type} }
		});

		if ($preader->doc_freq($term)) {
			# this may not show up deleted until optimized
			$preader->delete_term($term);
		}
	}
	$preader->close;

	my $writer = $self->_writer;
	for my $document (@documents) {
		my $doc = Plucene::Document->new;

		# combine our text fields into one, and then remove them; we
		# don't need them stored separately
		$document->{content} = join ' ', @{$document}{ @{$content{$type}} };
		delete @{$document}{ @{$content{$type}} };

		for my $key (keys %$document) {
			next unless length $document->{$key};
			my $field;

			if ($key eq 'content' || $text{$type}{$key}) {
				$field = Plucene::Document::Field->Text($key, $document->{$key});
			} elsif ($stored{$type}{$key}) {
				$field = Plucene::Document::Field->UnIndexed($key, $document->{$key});
			} else {
				$field = Plucene::Document::Field->Keyword($key, $document->{$key});
			}

			$doc->add($field);
		}

		$writer->add_document($doc);
	}

	warn "optimizing\n", $writer->optimize if $opts->{optimize};

	undef $writer;

	return;
}

#################################################################
sub prepRecord {
	my($self, $type, $data, $opts) = @_;

	return unless $type =~ $handled;
	$self->_type($type);

	# default to writer
	my $db = $opts->{db} || getCurrentDB();
	my %record;

	$data = { $primary{$type} => $data } unless ref $data;

	if ($type eq 'comments') {
		my $comment = $db->getComment($data->{cid}) or return {};
		for (qw(date points cid subject)) {
			$record{$_} = $comment->{$_};
		}

		$record{comment} = $data->{comment} || $db->getCommentText($data->{cid});

		my $discussion = $db->getDiscussion($comment->{sid});
		$record{discussion_id}    = $discussion->{id};
		$record{section}          = $discussion->{primaryskid};
		$record{topic}            = $discussion->{stoid}
			? $db->getStoryTopicsRendered($discussion->{stoid})
			: $discussion->{topic};
	}

	return \%record;
}

#################################################################
sub getRecords {
	my($self, $type, $data, $opts) = @_;

	return unless $type =~ $handled;
	$self->_type($type);

	# default to ... search?  reader?
	my $db = $opts->{db} || getObject('Slash::DB', { type => 'reader' });
	my %record;

	if ($type eq 'comments') {
		for my $datum (@$data) {
			# just return the whole comment ... why not?
			my $comment = $db->getComment($datum->{cid});
			$datum = $comment || {};
			if ($comment->{sid}) {
				my $discussion = $db->getDiscussion($comment->{sid});
				@{$datum}{qw(
					primaryskid url title
					author_uid did
				)} = @{$discussion}{qw(
					primaryskid url title
					uid id
				)};
			}
		}
	}
}

#################################################################
sub _fudge_data {
	my($data) = @_;

	my %processed;

	if ($data->{topic}) {
		my @topics = ref $data->{topic}
			? @{$data->{topic}}
			: $data->{topic};
		$processed{topic} = \@topics;
	} else {
		$processed{topic} = [];
	}

	if ($data->{section}) {
		# make sure we pass a skid
		if ($data->{section} =~ /^\d+$/) {
			$processed{section} = $data->{section};
		} else {
			my $reader = getObject('Slash::DB', { db_type => 'reader' });
			# get section name, for most compatibility with this API
			my $skid = $reader->getSkidFromName($data->{section});
			$processed{section} = $skid if $skid;
		}
	}

	return \%processed;
}

#################################################################
# make it easier to sort by serializing the date
sub _get_date {
	my($time, $format) = @_;
	$format ||= '%Y-%m-%d %H:%M:%S';
	return freeze_date(Time::Piece->strptime($time, $format));
}

#################################################################
# make it easier to sort by converting to alphabet
sub _get_points {
	my($points) = @_;

	my $constants = getCurrentStatic();
	my $min = $constants->{comment_minscore};
	my $max = $constants->{comment_maxscore};

	$points = $points < $min
		? $min
		: $points > $max
			? $max
			: $points;

	my $start  = $min;
	my $finish = 'a';
	until ($start == $points) {
		$start++;
		$finish++;
	}

	return $finish;
}

#################################################################
sub _type {
	my($self, $type) = @_;
	$self->{_type} = $type if defined $type;
	return $self->{_type};
}

#################################################################
sub _dir {
	my($self) = @_;
	return catdir(getCurrentStatic('datadir'), 'plucene', $self->_type);
}

#################################################################
sub _searcher {
	my($self) = @_;
	return Plucene::Search::IndexSearcher->new($self->_dir);
}

#################################################################
sub _reader {
	my($self) = @_;
	return Plucene::Index::Reader->open($self->_dir);
}

#################################################################
sub _writer {
	my($self) = @_;
	my $dir = $self->_dir;
	return Plucene::Index::Writer->new(
		$dir,
		Plucene::Analysis::Standard::StandardAnalyzer->new,
#		Plucene::Analysis::SimpleAnalyzer->new,
		-e catfile($dir, 'segments') ? 0 : 1
	);
}


#################################################################
#################################################################
package Slash::SearchToo::Plucene::Filter;
use base 'Plucene::Search::DateFilter';

sub new {
	my($self, $args) = @_;
	bless {
		field => $args->{field},
		from  => $args->{from},
		to    => $args->{to},
	}, $self;
}


1;

__END__
