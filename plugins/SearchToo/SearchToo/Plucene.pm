package Slash::SearchToo::Plucene;

# STILL IN PROGRESS NOT READY FOR USE

use strict;
use File::Spec::Functions;
use Slash::Utility;
use Slash::DB::Utility;
use Slash::SearchToo::Classic;
use base 'Slash::SearchToo::Indexer';

use Plucene::Document;
use Plucene::Document::DateSerializer;
use Plucene::Index::Writer;
use Plucene::QueryParser;
use Plucene::Search::HitCollector;
use Plucene::Search::IndexSearcher;
use Plucene::Search::TermQuery;

our $VERSION = $Slash::Constants::VERSION;

# FRY: I did it!  And it's all thanks to the books at my local library.

our $handled = qr{^(?:comments)$};

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
sub _findRecords {
	my($self, $results, $records, $sopts, $terms, $opts) = @_;

	my $constants = getCurrentStatic();

slashProf('init search', 'findRecords setup');

	my $parser = Plucene::QueryParser->new({
		analyzer => $self->_analyzer,
		default  => 'content'
	});

	my $querystring = $terms->{query};
	# escape special chars
	$querystring =~ s/([-+&|!{}[\]:\\])~*?/\\$1/g; # allowed: ()"^
	# normalize to lower case
	$querystring =~ s/\b(?!AND|NOT|OR)(\w+)\b/\L$1/g;
	my $newquery;
	eval { $newquery = $parser->parse('+(' . $querystring . ')') } or return $results;

	my $filter = 0;
	if (length $terms->{points_min}) {
		# no need to bother with adding this to the query, since it's all comments
		if ($terms->{points_min} == $constants->{comment_minscore}) {
			delete $terms->{points_min};
		} else { # ($terms{points_min} != $constants->{comment_maxscore}) {
			$filter = Slash::SearchToo::Plucene::Filter->new({
				field => '_points_',
				from  => _get_sortable_points(delete $terms->{points_min}),
				to    => _get_sortable_points($constants->{comment_maxscore}),
			});
		}
	}

	for my $key (keys %$terms) {
		next if $key eq 'query' || ! length($terms->{$key});
		my $term = Plucene::Index::Term->new({
			field	=> $key,
			text	=> $terms->{$key}
		}) or next;
		my $term_query = Plucene::Search::TermQuery->new({ term => $term }) or next;
		$newquery->add($term_query, 1);
	}
#use Data::Dumper;
#print STDERR Dumper $newquery;
#print STDERR $newquery->to_string, ":$filter\n";

	my $searcher = $self->_searcher or return $results;
slashProf('search', 'init search');
	my $docs = $searcher->search_top($newquery, $filter, $sopts->{start} + $sopts->{max});

	$sopts->{total}   = $searcher->max_doc;
	$sopts->{matches} = $docs->total_hits;

slashProf('fetch results', 'search');
	my $skip = $sopts->{start};
	for my $obj (sort { $b->{score} <=> $a->{score} } $docs->score_docs) {
		if ($skip > 0) {
			$skip--;
			next;
		}

		last if @$records >= $sopts->{max};

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

	return 1;
}

#################################################################
sub _addRecords {
	my($self, $type, $documents, $opts) = @_;

	my $writer = $self->_writer;

	my $count = 0;
	for my $document (@$documents) {
		my $doc = Plucene::Document->new;

		# combine our text fields into one, and then remove them; we
		# don't need them stored separately
		# normalize to lower case
		$document->{content} = lc join ' ', @{$document}{ @{$self->_field_list('content')} };
		delete @{$document}{ @{$self->_field_list('content')} };

		$document->{_date_}   = _get_sortable_date(delete $document->{date});
		$document->{_points_} = _get_sortable_points(delete $document->{points});

		for my $key (keys %$document) {
			next unless length $document->{$key};
			my $field;

			if ($key eq 'content' || $self->_field_exists(text => $key)) {
				$field = Plucene::Document::Field->Text($key, $document->{$key});
			} else {
				$field = Plucene::Document::Field->Keyword($key, $document->{$key});
			}

			$doc->add($field);
		}

		$writer->add_document($doc);
		$count++;
	}

	undef $writer;

	# only optimize if requested (as usual), and changes were made
	$self->optimize($type) if $opts->{optimize} && $count;

	return $count;

}

#################################################################
# Plucene-specific helper methods
sub isIndexed {
	my($self, $type, $id, $opts) = @_;

	return unless $self->_handled($type);

	my $preader = ($opts->{_reader} || $self->_reader) or return;

	my $term = Plucene::Index::Term->new({
		field	=> $self->_primary,
		text	=> $id
	});

	my $found = $preader->doc_freq($term);

	$preader->close unless $opts->{_reader};

	return $found ? ($found, $term) : 0;
}

#################################################################
sub optimize {
	my($self, $type) = @_;

	return unless $self->_handled($type);

slashProf('optimize');

	my $writer = $self->_writer;
	$writer->optimize;
	undef $writer;
slashProf('', 'optimize');

	return 1;
}

#################################################################
sub merge {
	my($self, $type, $dirs, $opts) = @_;

	return unless $self->_handled($type);

slashProf('merge');

	my @alldirs;
	for (@$dirs) {
		push @alldirs, $self->_dir($type => $_);
	}
	my $dir = $self->_dir($type => $opts->{dir});
	## backup $dir?

	if (@alldirs) {
		my $writer = $self->_writer;
		$writer->add_indexes(@alldirs);
	}

slashProf('', 'merge');

	return scalar @alldirs;
}

#################################################################
sub deleteRecords {
	my($self, $type, $ids, $opts) = @_;

	return unless $self->_handled($type);

slashProf('deleteRecords');

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

slashProf('', 'deleteRecords');

	return $count;
}

#################################################################
# make it easier to sort by serializing the date
sub _get_sortable_date {
	my($time, $format) = @_;
	$format ||= '%Y-%m-%d %H:%M:%S';
	return freeze_date(Time::Piece->strptime($time, $format));
}

#################################################################
# make it easier to sort by converting to alphabet
sub _get_sortable_points {
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
sub _searcher {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	return $self->{_searcher}{$type}{$dir} if $self->{_searcher}{$type}{$dir};

	return -e $dir
		? ($self->{_searcher}{$type}{$dir} = Plucene::Search::IndexSearcher->new($dir))
		: undef;
}

#################################################################
sub _reader {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	return $self->{_reader}{$type}{$dir} if $self->{_reader}{$type}{$dir};

	return -e $dir
		? ($self->{_reader}{$type}{$dir} = Plucene::Index::Reader->open($dir))
		: undef;
}

#################################################################
sub _writer {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	return $self->{_writer}{$type}{$dir} if $self->{_writer}{$type}{$dir};

	return $self->{_writer}{$type}{$dir} = Plucene::Index::Writer->new(
		$dir, $self->_analyzer,
		-e catfile($dir, 'segments') ? 0 : 1
	);
}

#################################################################
sub close_searcher {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	my $searcher = delete $self->{_searcher}{$type}{$dir} or return;
	$searcher->close;
}

#################################################################
sub close_reader {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	my $preader = delete $self->{_reader}{$type}{$dir} or return;
	$preader->close;
}

#################################################################
sub close_writer {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	my $writer = delete $self->{_writer}{$type}{$dir} or return;
	undef $writer;
}

# maybe add our own analyzer ...
use Plucene::Analysis::StopAnalyzer;
sub _analyzer {
	return Plucene::Analysis::StopAnalyzer->new;
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
