package Slash::SearchToo::Kinosearch;

# STILL IN PROGRESS NOT READY FOR USE

use strict;
use File::Path;
use File::Spec::Functions;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::SearchToo::Indexer';

use Search::Kinosearch::KSearch;
use Search::Kinosearch::Kindexer;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: I did it!  And it's all thanks to the books at my local library.

our $handled = qr{^(?:comments)$};

our $backend = 'DB_File';

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
	$querystring =~ s/\b(?!AND|NOT|OR)(\w+)\b/\L$1/g;

	$sopts->{max}++;  # until we get matches/num_hits working
	my $searcher_opts = {
		-num_results	=> $sopts->{max},
		-offset		=> $sopts->{start},
		-excerpt_field	=> $self->_field_list('content')->[0]
	};

	if ($sopts->{'sort'} == 1) {
		$searcher_opts->{-sort_by} = 'timestamp';
	} elsif ($sopts->{'sort'} == 2) {
		$searcher_opts->{-sort_by} = 'relevance';
	}

	my $searcher = $self->_searcher(undef, undef, $searcher_opts) or return $results;

	$searcher->add_query(
		-string    => $querystring,
		-lowercase => 1,
		-tokenize  => 1,
		-stem      => 1,
		-required  => 1,
		-fields    => join (' ', @{$self->_field_list('content')}),
	);


#	if (length $terms->{points_min}) { # ???
#		# no need to bother with adding this to the query, since it's all comments
#		if ($terms->{points_min} == $constants->{comment_minscore}) {
#			delete $terms->{points_min};
#		} else { # ($terms{points_min} != $constants->{comment_maxscore}) {
			delete $terms->{points_min};
#		}
#	}

	for my $key (keys %$terms) {
		next if $key eq 'query' || ! length($terms->{$key});

		$searcher->add_query(
			-string    => $terms->{$key},
			-required  => 1,
			-fields    => $key,
		);
	}

#use Data::Dumper;
#print Dumper $searcher;

slashProf('search', 'init search');
	my $status = $searcher->process;

#	$sopts->{total}   = $searcher->max_doc;
	$sopts->{matches} = $status->{num_hits};

slashProf('fetch results', 'search');

	while (my $obj = $searcher->fetch_result_hashref) {
		my %data = (
			score           => $obj->{score},
			$self->_primary => $obj->{doc_id},
			excerpt		=> $obj->{excerpt},
		);

		push @$records, \%data;
	}

slashProf('', 'fetch results');

use Data::Dumper;
print Dumper $records;

	return 1;
}

#################################################################
sub _addRecords {
	my($self, $type, $documents, $opts) = @_;

	my $writer = $self->_writer;

	if (1 || $writer->{_is_new}) { # ???
		for my $field (keys %{$documents->[0]}) {
			$writer->define_field(
				-name   => $field,
				# only store the main content field, for excerpting
				-store  => $self->_field_list('content')->[0] eq $field
			);
		}
	}

	my $count = 0;
	my @docs;
	for my $document (@$documents) {
		my %doc;
		# start new document by *id
		$writer->new_document($document->{ $self->_primary });

		# timestamp is Unix epoch
		if ($document->{date}) {
			$writer->set_document_timestamp(timeCalc(delete $document->{date}, "%s", 0));
		}
 
		for my $key (keys %$document) {
			next unless length $document->{$key};
			next if $key eq $self->_primary;

			$writer->set_field($key => $document->{$key});

			my $is_text    = $self->_field_exists(text    => $key);
			my $is_content = $self->_field_exists(content => $key);

			if ($is_text || $is_content) {
				$writer->lc_field($key) if $is_content;
				$writer->tokenize_field($key);
				$writer->stem_field($key) if $is_content;
			}
		}

		$writer->add_document;
		$count++;
	}

	$writer->finish;

#	# only optimize if requested (as usual), and changes were made
#	$self->optimize($type) if $opts->{optimize} && $count;

	return $count;
}

#################################################################
# Plucene-specific helper methods
sub isIndexed { # ???
	my($self, $type, $id, $opts) = @_;

	return unless $self->_handled($type);

	my $preader = ($opts->{_reader} || $self->_reader) or return;

	my $term = Plucene::Index::Term->new({
		field	=> $self->_primary,
		text	=> $id
	});

	my $found = $preader->doc_freq($term);

	$preader->close unless $opts->{_reader};

	return($found, $term) if $found;
}

#################################################################
sub optimize { # ???
	my($self, $type) = @_;

	return unless $self->_handled($type);

slashProf('optimize');

slashProf('', 'optimize');

	return 1;
}

#################################################################
sub merge { # ???
	my($self, $type, $dirs, $opts) = @_;

	return unless $self->_handled($type);

slashProf('merge');

	my @alldirs;
	for (@$dirs) {
		push @alldirs, $self->_dir($type => $_);
	}
	my $dir = $self->_dir($type => $opts->{dir});
	## backup $dir?

slashProf('', 'merge');

	return scalar @alldirs;
}

#################################################################
sub deleteRecords { # ???
	my($self, $type, $ids, $opts) = @_;

	return unless $self->_handled($type);

slashProf('deleteRecords');

	my $preader = $self->_reader or return;

	$ids = [ $ids ] unless ref $ids;

	my $count = 0;
	for my $id (@$ids) {
		my($found) = $self->isIndexed($type => $id, { _reader => $preader });
		if ($found) {
			$count += $found;
			$preader->delete_document($id);
		}
	}

#	# only optimize if requested (as usual), and changes were made
#	$self->optimize($type) if $opts->{optimize} && $count;

slashProf('', 'deleteRecords');

	return $count;
}

#################################################################
sub _searcher {
	my($self, $type, $dir, $opts) = @_;
	$dir = $self->_dir($type, $dir);

	my $constants = getCurrentStatic();
	$opts ||= {};

	my $preader = $self->_reader($type) or return undef;

	return Search::Kinosearch::KSearch->new(
		-stoplist		=> {},
		-kindex			=> $preader,
		-any_or_all		=> 'all',
		-sort_by		=> 'relevance', # relevance, timestamp
		-allow_boolean		=> 0,
		-allow_phrases		=> 0,
#		-max_terms		=> 6, # ???
		-excerpt_length		=> $constants->{search_text_length},
		%$opts
	);
}

#################################################################
sub _reader {
	my($self, $type, $dir) = @_;
	$dir = $self->_dir($type, $dir);

	return undef unless -e catdir($dir, 'kindex');

	return Search::Kinosearch::Kindexer->new(
		-stoplist		=> {},
		-mode			=> 'readonly',
		-backend		=> $backend,
		-kindexpath		=> catdir($dir, 'kindex'),
		-kinodatapath		=> catdir($dir, 'kindex', 'kinodata'),
	);
}

#################################################################
sub _writer {
	my($self, $type, $dir) = @_;
	$dir = $self->_dir($type, $dir);

	my $mode = -e catdir($dir, 'kindex') ? 'overwrite' : 'create';

	mkpath($dir, 0, 0775) unless -e $dir;

	return Search::Kinosearch::Kindexer->new(
		-stoplist		=> {},
		-mode			=> $mode, # create, overwrite, update, readonly
		-backend		=> $backend,
		-kindexpath		=> catdir($dir, 'kindex'),
		-kinodatapath		=> catdir($dir, 'kindex', 'kinodata'),
		-temp_directory		=> File::Spec::Functions::tmpdir(),
		-enable_updates		=> 0,
		-phrase_matching	=> 0,
	);
}

1;

__END__
