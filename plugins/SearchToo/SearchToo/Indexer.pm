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
use base 'Slash::SearchToo::Classic';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: I did it!  And it's all thanks to the books at my local library.

# This is a superclass for various SearchToo engines that do indexing etc.


#################################################################
# fields that will be combined into the content field,
# for indexing and tokenization; first field is main one to excerpt
our %content = (
	comments	=> [qw(comment subject)],
	stories		=> [qw(introtext bodytext title)],
);

# additional fields that will be indexed and tokenized
our %text = (
	comments	=> [ qw(tids) ],
	stories		=> [ qw(tids) ],
);

our %primary = (
	comments	=> 'cid',
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
	{ no strict;
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
	return Slash::SearchToo::Classic::findRecords(@_) unless $self->_handled($type);

slashProfInit();
slashProf('findRecords setup');

	my $constants = getCurrentStatic();

	my $processed = $self->_fudge_data($query);
	my $results = {};
	my $records = [];

	### set up common query terms
	my $terms = {
		query	=> $query->{query},
	};


	### set up common options
	my $sopts = {};
	$sopts->{total}   = 0;
	$sopts->{matches} = 0;
	$sopts->{start}   = $opts->{records_start} || 0;
	$sopts->{max}     = $opts->{records_max}   || $constants->{search_default_display};

	# sort can be an arrayref, but stick with one for now
	## no way to sort by date yet
	$sopts->{sort} = ref $opts->{sort} ? $opts->{sort}[0] : $opts->{sort};
	$sopts->{sort} = ($opts->{sort} eq 'date'	|| $opts->{sort} eq 1) ? 1 :
			($opts->{sort} eq 'relevance'	|| $opts->{sort} eq 2) ? 2 :
			0;

	### dispatch to different queries
	if ($type eq 'comments') {
		for (qw(section)) {
			$terms->{$_} = $processed->{$_} if $processed->{$_};
		}
		%$terms = (%$terms,
			sid		=> $query->{sid},
			points_min	=> $query->{points_min},
		);
	}

slashProf('_findRecords', 'findRecords setup');
	$self->_findRecords($results, $records, $sopts, $terms, $opts);
slashProf('getRecords', '_findRecords');
	$self->getRecords($type => $records);
slashProf('prepResults', 'getRecords');
	$self->prepResults($results, $records, $sopts);
slashProf('', 'getRecords');

slashProfEnd();

	return $results;


}

#################################################################
sub addRecords {
	my($self, $type, $data, $opts) = @_;

	return unless $self->_handled($type);

slashProfInit();
slashProf('addRecords setup');

	$data = [ $data ] unless ref $data eq 'ARRAY';

	my @documents;

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
		}

		push @documents, \%document;
	}

	# so we can index outside the main dir
	if ($opts->{dir}) {
		$self->_dir($opts->{dir});
	}

	# only bother if not adding, i.e., if modifying; if adding we
	# assume it is new
	unless ($opts->{add}) {
		$self->deleteRecords($type => [ map $_->{ $self->{_fields}{primary}{$type} }, @documents ]);
	}

slashProf('add docs', 'prepare records');

	my $count = $self->_addRecords($type, \@documents, $opts);

slashProf('', 'add docs');

	# clear it out when we're done
	if ($opts->{dir}) {
		$self->_dir('');
	}

slashProfEnd();

	return $count;
}

#################################################################
sub prepRecord {
	my($self, $type, $data, $opts) = @_;

	return unless $self->_handled($type);

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

	return unless $self->_handled($type);

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
	}
}

#################################################################
# handle delete too?
sub storeRecords {
	my($self, $type, $data, $opts) = @_;

	return unless $self->_handled($type);

	my $slashdb = getCurrentDB();

	$data = [ $data ] unless ref $data eq 'ARRAY';

	my $count = 0;
	for my $record (@$data) {
		next unless keys %$record;

		# deal with multiple instances of same type => id
		$count++ if $slashdb->sqlInsert('search_index_dump', {
			type	=> $type,
			id	=> $record,
			status	=> $opts->{add} ? 'new' : 'changed',
		});
	}

	return $count;
}

#################################################################
# move prepared index data to live
sub moveLive {
	my($self, $type, $dir) = @_;

	return unless $self->can('_dir') && ($dir || $self->can('_backup_dir'));

	my $backup_dir = $self->_backup_dir($type, $dir);
	my $dir = $self->_dir($type, '');

	my @time = localtime;
	my $now = sprintf "-%04d%02d%02d-%02d%02d%02d", $time[5]+1900, $time[4]+1, $time[3], $time[2], $time[1], $time[0];
	$dir =~ s|/+$||; # just in case
	my $olddir = $dir . $now;
	my $tmpdir = $dir . '-tmp';

	# copy staging to temp dir
	_moveFind($backup_dir, $tmpdir);
	# move live to backup
	rename($dir, $olddir);
	# move temp to live
	rename($tmpdir, $dir);

	# kick old?
}

#################################################################
sub _moveFind {
	my($olddir, $newdir);
	find(sub {
		my($old) = $File::Find::name;
		my $new = s/^\Q$olddir/$newdir/;
		if (-d $old) {
			eval {
				mkpath($new, 0, 0775);
			};
			if ($@) {
				warn "Can't create path $new: $@";
			}
		} elsif (-f _) {
			copy($old, $new) or warn "Can't copy file $new: $!";
		}
	}, $olddir);
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
sub _handled {
	my($self, $type) = @_;
	$type = $self->_type($type);
	return $type =~ $self->{_handled};
}

#################################################################
sub _type {
	my($self, $type) = @_;
	$self->{_type} = $type if defined $type;
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
	my($self, $type, $dir) = @_;
	$self->{_dir} = $dir if defined $dir;
	$self->{_dir} ||= catdir(getCurrentStatic('datadir'), 'search_index');

	return catdir($self->{_dir}, $self->_class, $self->_type($type));
}

#################################################################
sub _backup_dir {
	my($self, $type, $dir) = @_;
	my $backup_dir = $dir || catdir(getCurrentStatic('datadir', 'search_index_tmp'));

	return $self->_dir($type, $backup_dir);
}

1;

__END__
