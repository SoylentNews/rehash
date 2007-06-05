package Slash::SearchToo::Indexer;

use strict;
use File::Copy;
use File::Find;
use File::Path;
use File::Spec::Functions;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::SearchToo';
require Slash::SearchToo::Classic;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: I did it!  And it's all thanks to the books at my local library.

# This is a superclass for various SearchToo engines that do indexing etc.


#################################################################
# fields that will be combined into the content field,
# for indexing and tokenization; first field is main one to excerpt
our %content = (
#	comments	=> [qw(comment subject)],
#	stories		=> [qw(introtext bodytext title)],
	firehose	=> [qw(introtext bodytext title section topics name toptags)],
);

# additional fields that will be indexed and tokenized
our %text = (
#	comments	=> [ qw(tids) ],
#	stories		=> [ qw(tids) ],
	firehose	=> [ qw(note dayssince1970) ],
);

# will be indexed, not tokenized
our %primary = (
#	comments	=> 'cid',
	firehose	=> 'id',
);

# turn into hashes
for my $hash (\%text, \%content) {
	for my $type (keys %$hash) {
		my $arr = $hash->{$type};
		$hash->{$type} = { map { ($_ => 1) } @$arr };
		$hash->{_array}{$type} = $arr;
	}
}

#################################################################
sub new {
	my($class, $user) = @_;
	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'SearchToo'};

	my $handled;
	{ no strict 'refs';
		$handled = ${$class . '::handled'};
	}

	my $self = {
		_fields => {
			content => \%content,
			text	=> \%text,
			primary	=> \%primary,
		},
	};
	$self->{_handled} = $handled if $handled;

	bless $self, $class;
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################
sub findRecords {
	my($self, $type, $query, $opts) = @_;

	# let Classic handle for now
	return Slash::SearchToo::Classic::findRecords(@_) unless $self->handled($type);

slashProfInit();
slashProf('findRecords setup');

	my $constants = getCurrentStatic();

	my $processed = $self->_fudge_data($query);
	my $results = {};
	my $records = [];

	### set up common query terms
	my $terms = {
		query	=> delete $query->{query},
	};


	### set up common options
	my $sopts = {};
	$sopts->{total}   = 0;
	$sopts->{matches} = 0;
	$sopts->{start}   = $opts->{records_start} || 0;
	$sopts->{max}     = defined $opts->{records_max} && length $opts->{records_max}
		? $opts->{records_max}
		: $constants->{search_default_display};

	# sort can be an arrayref, but stick with one for now
	## no way to sort by date yet
	# 0: none, 1: date, 2: relevance, 3: handle by caller
	$sopts->{sort} = ref $opts->{sort} ? $opts->{sort}[0] : $opts->{sort};
	$sopts->{sort} = ($opts->{sort} && $opts->{sort} eq 'date'	|| $opts->{sort} eq 1) ? 1 :
			 ($opts->{sort} && $opts->{sort} eq 'relevance'	|| $opts->{sort} eq 2) ? 2 :
			 ($opts->{sort} && $opts->{sort} eq 'caller'	|| $opts->{sort} eq 3) ? 3 :
			 $opts->{sort} || 0;
	# 1: asc, 0: none specified, -1: desc
	$sopts->{sortdir} = $opts->{sortdir} || 0;

	### dispatch to different queries
	if ($type eq 'comments') {
		for (qw(section)) {
			$terms->{$_} = $processed->{$_} if $processed->{$_};
		}
		%$terms = (%$terms,
			sid		=> $query->{sid},
			points_min	=> $query->{points_min},
		);
	} else {
		%$terms = (%$terms, %$query);
	}

slashProf('_findRecords', 'findRecords setup');
	$self->_findRecords($results, $records, $sopts, $terms, $opts);
slashProf('getRecords', '_findRecords');
	$self->getRecords($type => $records, {
		alldata		=> 1,
		sort		=> $sopts->{sort},
		sortdir		=> $sopts->{sortdir},
		limit		=> $sopts->{max} || $sopts->{matches},
		offset		=> $sopts->{start},
		carryover	=> $opts->{carryover}
	});
slashProf('prepResults', 'getRecords');
	$self->prepResults($results, $records, $sopts);
slashProf('', 'getRecords');

slashProfEnd();

	return $results;


}

#################################################################
sub addRecords {
	my($self, $type, $data, $opts) = @_;

	return unless $self->handled($type);
	return unless $data;

slashProfInit();
slashProf('addRecords setup');

	$data = [ $data ] unless ref $data eq 'ARRAY';

	my(@documents, @delete);

slashProf('prepare records', 'addRecords setup');

	for my $record (@$data) {
		next unless keys %$record;
		my $processed = $self->_fudge_data($record);
		my %document;

		if ($type eq 'comments') {
			%document = (
				cid			=> $record->{cid},

				date			=> $record->{date},
				points			=> $record->{points},

				comment			=> $record->{comment},
				subject			=> $record->{subject},
				sid			=> $record->{discussion_id},

				primaryskid		=> $processed->{section},
				tids			=> join(' ', @{$processed->{topic}}),
			);

		} elsif ($type eq 'firehose') {
			%document = (
				id			=> $record->{id},

				date			=> $processed->{date},
				dayssince1970		=> $processed->{dayssince1970},

				introtext		=> $record->{introtext},
				bodytext		=> $record->{bodytext},
				title			=> $record->{title},

				type			=> $record->{type},
				category		=> $record->{category} || 'none',
				note			=> $record->{note},
				popularity		=> $record->{popularity},
				activity		=> $record->{activity},
				editorpop		=> $record->{editorpop},
				accepted		=> $record->{accepted},
				rejected		=> $record->{rejected},
				public			=> $record->{public},
				toptags			=> $record->{toptags},

				primaryskid		=> $processed->{section},
				tids			=> join(' ', @{$processed->{topic}}),
				section			=> $processed->{section_name},
				topics			=> join(' ', @{$processed->{topic_names}}),
				name			=> $processed->{uid_name},
			);
		}

		if (keys %document) {
			# only bother if modifying
			if ($record->{status} eq 'changed' || $record->{status} eq 'deleted') {
				push @delete, $document{ $self->_primary };
			}

			push @documents, \%document;
		}
	}

	$self->deleteRecords($type => \@delete) if @delete;

slashProf('add docs', 'prepare records');

	my $count = $self->_addRecords($type, \@documents, $opts) if @documents;

slashProf('', 'add docs');

slashProfEnd();

	return $count;
}

#################################################################
sub prepRecord {
	my($self, $type, $data, $opts) = @_;

	return unless $self->handled($type);

	# default to writer
	my $db = $opts->{db} || getCurrentDB();
	my %record;

	$data = { $primary{$type} => $data } unless ref $data;

	# this could possibly be done to get a bunch of comments at once ...
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

	return unless $self->handled($type);

	# default to ... search?  reader?
	my $db = $opts->{db} || getObject('Slash::DB', { type => 'reader' });
	my %record;

	if ($type eq 'comments') {
		for my $datum (@$data) {
			# just return the whole comment ... why not?
			my $comment = $db->getComment($datum->{cid});
			if ($comment) {
				@{$datum}{keys %$comment} = values %$comment;
			} else {
				$datum = {};
				next;
			}
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
	} elsif ($type eq 'firehose') {
		my @newdata;
		my $fh_sort = $opts->{sort};

		my $firehose = getObject('Slash::FireHose', { db_type => 'reader' }) or return;
		my($items) = $firehose->getFireHoseEssentials({
			ids		=> [ map { $_->{id} } @$data ],
			fetch_text	=> 1,
			no_search	=> 1,
			nolimit		=> !$fh_sort,
			carryover	=> $opts->{carryover},
			limit		=> $opts->{limit},
			offset		=> $opts->{offset}
		});

		my %data_h = map { $_->{id} => $_ } @$data;

		for my $item (@$items) {
			my($datum) = $data_h{ $item->{id} };
			if ($opts->{alldata}) {
				@{$datum}{keys %$item} = values %$item;
			} else {
				@{$datum}{qw(
					introtext bodytext title category note
					globjid uid primaryskid tid type date
					popularity activity editorpop
					accepted rejected public toptags
				)} = @{$item}{qw(
					introtext bodytext title category note
					globjid uid primaryskid tid type createtime
					popularity activity editorpop
					accepted rejected public toptags
				)};
			}
			# inherit sort order from FireHose, which
			# defaults to date ordering
			push @newdata, $datum if $fh_sort;
		}
		if ($fh_sort) {
			@{$data} = @newdata;
		}
	}
}

#################################################################
sub storeRecords {
	my($self, $type, $data, $opts) = @_;

	return unless $self->handled($type);

	my $slashdb = getCurrentDB();

	$data = [ $data ] unless ref $data eq 'ARRAY';

	my $count = 0;
	for my $record (@$data) {
		next unless defined $record;
		unless (ref $record) {
			next unless length $record;
			$record = { id => $record };
		}
		next unless keys %$record;

		# deal with multiple instances of same type => id
		$count++ if $slashdb->sqlInsert('search_index_dump', {
			-iid	=> 'NULL',
			id	=> $record->{id},
			type	=> $type,
			status	=> $opts->{changed} ? 'changed' : $opts->{deleted} ? 'deleted' : 'new'
		});
	}

	return $count;
}

#################################################################
sub getStoredRecords {
	my($self) = @_;

	my $slashdb = getCurrentDB();
	my $records = $slashdb->sqlSelectAllHashrefArray('iid, id, type, status', 'search_index_dump');

	my $return = {};
	for my $record (@$records) {
		if ($self->handled($record->{type})) {
			push @{$return->{ $record->{type} }}, $record;
		}
	}

	return $return;
}

#################################################################
sub deleteStoredRecords {
	my($self, $iids) = @_;

	my $slashdb = getCurrentDB();

	return if !$iids;
	$iids = [ $iids ] unless ref $iids eq 'ARRAY';
	return if !@$iids;
	my $iid_str = join ',', map { $slashdb->sqlQuote($_) } @$iids;

	my $count = $slashdb->sqlDelete('search_index_dump', "iid IN ($iid_str)");
	return $count;
}

#################################################################
# move prepared index data to live
# basic procedure:
# * copy live index to backup
# * modify backup
# * make backup -> live
# rinse, lather, repeat
sub moveLive {
	my($self) = @_;

	# fix permissions ... KS makes it 0600 by default
	my $dir = $self->_dir;
	find(sub {
		chmod 0644, $File::Find::name if -f $File::Find::name;
	}, $dir);

	my $slashdb = getCurrentDB();
	my $num = $slashdb->getVar('search_too_index_num', 'value', 1) || 0;

	# make backup dir -> live dir
	$slashdb->setVar('search_too_index_num', ($num == 1 ? 0 : 1));
}

sub copyBackup {
	my($self) = @_;

	my $slashdb = getCurrentDB();
	my $num = $slashdb->getVar('search_too_index_num', 'value', 1) || 0;
	my $bnum = $num == 1 ? 0 : 1;

	my $dir = $self->_dir;
	my $dh;
	if (!opendir($dh, $dir)) {
		warn "Can't open dir '$dir': $!\n";
		return;
	}

	my @to_copy = grep { /^(.+)_$num$/ } readdir $dh;
	closedir $dh;

	for my $item (@to_copy) {
		$item =~ /^(.+)_$num$/;
		my $type = $1;
		my $live = catdir($dir, $item);
		my $back = catdir($dir, $type . "_$bnum");

#		rmtree($back) if -d $back;
		mkpath($back) unless -d $back;
		find(sub {
			my($backf) = $File::Find::name;
			(my $livef = $backf) =~ s/^\Q$back/$live/;

			if (! -e $livef) {
				if (-d $backf) {
					eval {
						rmtree($backf);
					};
					if ($@) {
						warn "Can't remove path '$backf': $@";
					}
				} elsif (-f _) {
					unlink $backf or warn "Can't remove file '$backf': $!";
				}
			}
		}, $back);


		find(sub {
			my($livef) = $File::Find::name;
			(my $backf = $livef) =~ s/^\Q$live/$back/;

			if (-d $livef) {
				eval {
					mkpath($backf, 0, 0775) unless -d $backf;
				};
				if ($@) {
					warn "Can't create path $backf: $@";
				}
			} elsif (-f _) {
				my $copy = 0;
				my @stat = stat(_);
				if (-f $backf) {
					my @nstat = stat($backf);
					# size, time
					if ($stat[7] != $nstat[7] || $stat[9] != $nstat[9]) {
						$copy = 1;
					}
				} else {
					$copy = 1;
				}

				if ($copy) {
					copy($livef, $backf) or warn "Can't copy file $backf: $!";
					utime($stat[9], $stat[9], $backf);
				}
			}
		}, $live);
	}
}

#################################################################
sub _field_exists {
	my($self, $field, $key, $type) = @_;
	return unless $field;
	$type = $self->_type($type);

	return $self->{_fields}{$field}{$type}{$key};
}

#################################################################
sub _field_list {
	my($self, $field, $type) = @_;
	return unless $field;
	$type = $self->_type($type);

	return $self->{_fields}{$field}{_array}{$type};
}

#################################################################
sub _primary {
	my($self, $type) = @_;
	$type = $self->_type($type);

	return $self->{_fields}{primary}{$type};
}

#################################################################
sub handled {
	my($self, $type) = @_;
	$type = $self->_type($type);
	return $type =~ $self->{_handled};
}

#################################################################
sub _type {
	my($self, $type) = @_;
	$self->{_type} = lc $type if defined $type;
	return $self->{_type};
}

#################################################################
sub _class {
	my($self) = @_;
	unless ($self->{_class}) {
		($self->{_class} = lc ref $self) =~ s/^.+:://;
	}
	return $self->{_class};
}

#################################################################
sub _dir {
	my($self, $type, $dir, $backup) = @_;

	$dir ||= catdir(getCurrentStatic('datadir'), 'search_index');

	my $class = $self->_class;
	if (!$type) {
		return $dir =~ /\Q$class\E$/
			? $dir
			: catdir($dir, $class);
	}

	my $slashdb = getCurrentDB();
	my $num = $slashdb->getVar('search_too_index_num', 'value', 1) || 0;
	if ($backup || $self->{_backup}) { # only works with two dirs for now ...
		$num = $num == 1 ? 0 : 1;
	}

	my $foodir = catdir($class, $self->_type($type) . "_$num");
	return $dir =~ /\Q$foodir\E$/
		? $dir
		: catdir($dir, $foodir);
}

#################################################################
sub backup {
	my($self, $on) = @_;
	$self->{_backup} = $on;
}

1;

__END__
