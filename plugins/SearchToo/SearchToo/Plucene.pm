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

use Plucene::Document;
use Plucene::Document::DateSerializer;
use Plucene::Index::Writer;
use Plucene::QueryParser;
use Plucene::Search::HitCollector;
use Plucene::Search::IndexSearcher;
use Plucene::Search::TermQuery;

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

# how to return results sorted by date?
# remove croaks from QueryParser->parse

	my $parser = Plucene::QueryParser->new({
		analyzer => $self->_analyzer,
		default  => 'content'
	});

	my $querystring = $terms{query};
	# escape special chars
	$querystring =~ s/([-+&|!{}[\]:\\])~*?/\\$1/g; # allowed: ()"^
	# normalize to lower case
	$querystring =~ s/\b(?!AND|NOT|OR)(\w+)\b/\L$1/g;
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
#print STDERR $newquery->to_string, "\n";

	my $searcher = $self->_searcher or return $results;
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

	# only bother if not adding, i.e., if modifying; if adding we
	# assume it is new
	unless ($opts->{add}) {
		$self->deleteRecords($type => [ map $_->{ $primary{$type} }, @documents ]);
	}

	my $writer = $self->_writer;
	my $count = 0;
	for my $document (@documents) {
		my $doc = Plucene::Document->new;

		# combine our text fields into one, and then remove them; we
		# don't need them stored separately
		# normalize to lower case
		$document->{content} = lc join ' ', @{$document}{ @{$content{$type}} };
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
		$count += 1;
	}

	undef $writer;

	# only optimize if requested (as usual), and changes were made
	$self->optimize($type) if $opts->{optimize} && $count;

	return $count;
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
# Plucene-specific helper methods
sub isIndexed {
	my($self, $type, $id, $opts) = @_;

	return unless $type =~ $handled;
	$self->_type($type);

	my $preader = ($opts->{_reader} || $self->_reader) or return;

	my $term = Plucene::Index::Term->new({
		field	=> $primary{$type},
		text	=> $id
	});

	my $found = $preader->doc_freq($term);

	$preader->close unless $opts->{_reader};

	return($found, $term) if $found;
}

#################################################################
sub optimize {
	my($self, $type) = @_;

	return unless $type =~ $handled;
	$self->_type($type);

	my $writer = $self->_writer;
	warn "optimizing\n";
	$writer->optimize;
	undef $writer;
}

#################################################################
sub deleteRecords {
	my($self, $type, $ids, $opts) = @_;

	return unless $type =~ $handled;
	$self->_type($type);

	my $preader = $self->_reader or return;

	$ids = [ $ids ] unless ref $ids;

	my $count = 0;
	for my $id (@$ids) {
		my($found, $term) = $self->isIndexed($type => $id, { _reader => $preader });
		if ($found) {
			$count += $found;
			$preader->delete_term($term);
		}
	}

	$preader->close;

	# only optimize if requested (as usual), and changes were made
	$self->optimize($type) if $opts->{optimize} && $count;

	return $count;
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
	my($self, $type) = @_;
	return catdir(getCurrentStatic('datadir'), 'plucene', $self->_type($type));
}

#################################################################
sub _searcher {
	my($self, $type) = @_;
	my $dir = $self->_dir($type);
	return -e $dir ? Plucene::Search::IndexSearcher->new($dir) : undef;
}

#################################################################
sub _reader {
	my($self, $type) = @_;
	my $dir = $self->_dir($type);
	return -e $dir ? Plucene::Index::Reader->open($dir) : undef;
}

#################################################################
sub _writer {
	my($self, $type) = @_;
	my $dir = $self->_dir($type);
	return Plucene::Index::Writer->new(
		$dir, $self->_analyzer,
		-e catfile($dir, 'segments') ? 0 : 1
	);
}

# maybe add our own analyzer ...
use Plucene::Analysis::Standard::StandardAnalyzer;
sub _analyzer {
	return Plucene::Analysis::Standard::StandardAnalyzer->new;
#	return Plucene::Analysis::SimpleAnalyzer->new;
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
