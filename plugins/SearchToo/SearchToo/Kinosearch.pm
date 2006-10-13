package Slash::SearchToo::Kinosearch;

# STILL IN PROGRESS NOT READY FOR USE

use strict;
use File::Path;
use File::Spec::Functions;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::SearchToo::Indexer';

use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Index::IndexReader;
use KinoSearch::InvIndexer;
use KinoSearch::Search::QueryFilter;
use KinoSearch::Searcher;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: I did it!  And it's all thanks to the books at my local library.

our $handled = qr{^(?:firehose)$}; #comments|

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

slashProf('init search');

	my $querystring = $terms->{query};
	# escape special chars
	# none, allow all special chars
#	$querystring =~ s/([&^|!{}[\]:\\])~*?/\\$1/g; # allowed: ()"+-
	# normalize to lower case ???
#	$querystring =~ s/\b(?!AND NOT|AND|OR)(\w+)\b/\L$1/g;
	# no field specifiers
	$querystring =~ s/://g;
	# collapse spaces
	$querystring =~ s/\s+/ /g;
	# for now, no non-alphas, until we are sure they cannot be used against us ...
	$querystring =~ s/[^\w -]+//g;


#	if ($sopts->{'sort'} == 1) {
#		$searcher_opts->{-sort_by} = 'timestamp';
#	} elsif ($sopts->{'sort'} == 2) {
#		$searcher_opts->{-sort_by} = 'relevance';
#	}

	my $preader  = $self->_reader or return $results;
	my $searcher = $self->_searcher or return $results;

	my $content_fields = $self->_field_list('content');
	if ($self->_type eq 'firehose') {
		push @$content_fields, 'note' if getCurrentUser('is_admin');
	}

	my $query_parser = KinoSearch::QueryParser::QueryParser->new(
		analyzer	=> $self->{_analyzers}{content},
		fields		=> $content_fields,
		default_boolop	=> 'AND',
	);
	my $query = $query_parser->parse($querystring);

	my($filter, @filters);
	for my $t (keys %$terms) {
		next if $t eq 'query';
		next if	!$terms->{$t} || !length($terms->{$t});

		push @filters, KinoSearch::Search::TermQuery->new(
			term => KinoSearch::Index::Term->new($t => $terms->{$t})
		);
	}

	if (@filters) {
		my $fquery = KinoSearch::Search::BooleanQuery->new;
		for my $f (@filters) {
			$fquery->add_clause(query => $f, occur => 'MUST');
		}
		$filter = KinoSearch::Search::QueryFilter->new(
			query => $fquery
		);
	}


#	if (length $terms->{points_min}) { # ???
#		# no need to bother with adding this to the query, since it's all comments
#		if ($terms->{points_min} == $constants->{comment_minscore}) {
#			delete $terms->{points_min};
#		} else { # ($terms{points_min} != $constants->{comment_maxscore}) {
#			delete $terms->{points_min};
#		}
#	}

slashProf('search', 'init search');
	my $hits = $searcher->search(query => $query, filter => $filter);

	$hits->seek($sopts->{start}, $sopts->{max});

	$sopts->{total}   = $preader->num_docs;
	$sopts->{matches} = $hits->total_hits;

slashProf('fetch results', 'search');
 	while (my $hit = $hits->fetch_hit_hashref) {
		my %data = (
			score           => $hit->{score},
			$self->_primary => $hit->{ $self->_primary },
		);
		push @$records, \%data;
	}

slashProf('', 'fetch results');

	return 1;
}

#################################################################
sub _addRecords {
	my($self, $type, $documents, $opts) = @_;

	my $writer = $self->_writer;

	for my $field (keys %{$documents->[0]}) {
		my $is_text    = $self->_field_exists(text    => $field);
		my $is_content = $self->_field_exists(content => $field);
		my $is_primary = $self->_primary eq $field;

		my $analyzer;
		if ($is_content) {
			$analyzer = $self->{_analyzers}{content};
		} elsif ($is_text) {
			$analyzer = $self->{_analyzers}{text};
		}

		$writer->spec_field(
			name    	=> $field,
			analyzer	=> $analyzer,
			analyzed	=> $analyzer ? 1 : 0,
			# no reason to be here at all if we won't index!
			indexed		=> 1,
			#compressed	=> 0, # ???
			# store only the ID so we can use it to look up other
			# data we need from the DB later
			stored  	=> $is_primary ? 1 : 0,
			vectorized	=> 0,
		);
	}

	my $count = 0;
	my @docs;
	for my $document (@$documents) {
		my $doc = $writer->new_doc;
		$doc->set_value(id => $document->{ $self->_primary });

		for my $field (keys %$document) {
			next unless defined $document->{$field} && length $document->{$field};
			next if $field eq $self->_primary;

			$doc->set_value($field => $document->{$field});
		}

		$writer->add_doc($doc);
		$count++;
	}

	# only optimize if requested (as usual), and changes were made
	$writer->finish(
		optimize => $opts->{optimize} && $count
	);

	$self->close_writer;

	return $count;
}

#################################################################
sub isIndexed {
	my($self, $type, $id, $opts) = @_;

	return unless $self->handled($type);

	my $searcher = $self->_searcher or return;

	my $query = KinoSearch::Search::TermQuery->new(
		term => KinoSearch::Index::Term->new($self->_primary => $id)
	);
	my $hits = $searcher->search(query => $query);

	return $hits->total_hits || 0;
}

#################################################################
sub deleteRecords {
	my($self, $type, $ids, $opts) = @_;

	return unless $self->handled($type);

	my $writer = $self->_writer or return;

slashProf('deleteRecords');

	$ids = [ $ids ] unless ref $ids;

	my $count = 0;
	for my $id (@$ids) {
		my($found) = $self->isIndexed($type => $id);
		if ($found) {
			$count += $found;
			$writer->delete_docs_by_term(
				KinoSearch::Index::Term->new($self->_primary => $id)
			);
		}
	}

	# only optimize if requested (as usual), and changes were made
	$writer->finish(
		optimize => $opts->{optimize} && $count
	);

	$self->close_writer;

slashProf('', 'deleteRecords');

	return $count;
}

#################################################################
sub _searcher {
	my($self, $type, $dir, $opts) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	return $self->{_searcher}{$type}{$dir} if $self->{_searcher}{$type}{$dir};

	$self->_analyzers;

	return $self->{_searcher}{$type}{$dir} = KinoSearch::Searcher->new(
		invindex		=> $self->_kdir($dir),
		analyzer		=> $self->{_analyzers}{content},
	);

#		-stoplist		=> {},
#		-kindex			=> $preader,
#		-any_or_all		=> 'all',
#		-sort_by		=> 'relevance', # relevance, timestamp
#		-allow_boolean		=> 0,
#		-allow_phrases		=> 0,
##		-max_terms		=> 6, # ???
#		-excerpt_length		=> $constants->{search_text_length},

}

#################################################################
sub _reader {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	return $self->{_reader}{$type}{$dir} if $self->{_reader}{$type}{$dir};

	my $kdir = $self->_kdir($dir);
	return undef unless -e $kdir;

	return $self->{_reader}{$type}{$dir} = KinoSearch::Index::IndexReader->new(
		invindex		=> $kdir,
	);
}

#################################################################
sub _writer {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	return $self->{_writer}{$type}{$dir} if $self->{_writer}{$type}{$dir};

	mkpath($dir, 0, 0775) unless -e $dir;

	$self->_analyzers;

	my $kdir = $self->_kdir($dir);
	return $self->{_writer}{$type}{$dir} = KinoSearch::InvIndexer->new(
		invindex		=> $kdir,
		create			=> -e $kdir ? 0 : 1,
		analyzer		=> $self->{_analyzers}{content},
	);
}

#################################################################
sub _kdir {
	my($self, $dir) = @_;
	return catdir($dir, 'invindex');
}

#################################################################
sub _analyzers {
	my($self) = @_;
	$self->{_analyzers}{content} ||= KinoSearch::Analysis::PolyAnalyzer->new(
		language  => 'en',
	);

	$self->{_analyzers}{text}    ||= KinoSearch::Analysis::Tokenizer->new(
		language  => 'en',
	);
}

#################################################################
sub close_searcher {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	my $searcher = delete $self->{_searcher}{$type}{$dir} or return;
}

#################################################################
sub close_reader {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	my $preader = delete $self->{_reader}{$type}{$dir} or return;
}

#################################################################
sub close_writer {
	my($self, $type, $dir) = @_;
	$type = $self->_type($type);
	$dir = $self->_dir($type, $dir);

	my $writer = delete $self->{_writer}{$type}{$dir} or return;
}

1;

__END__
