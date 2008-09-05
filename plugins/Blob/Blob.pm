# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Blob;

use strict;
use MIME::Types;
use Digest::MD5 'md5_hex';
use Slash;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# When this plugin was first written, it used a hardcoded hash to
# store MIME types.  Now we use the MIME::Types module.  But for
# backwards compatibility, here are the overrides for just the
# four types where our hardcoded hash differed from the (current)
# values returned by MIME::Types.  Honestly my guess is that
# MIME::Types is right and we were wrong, and we should remove
# this (except for 'text'), but for now, let's make it completely
# backwards compatible.

my %mimetype_overrides = (
	mp3  => 'audio/mp3',
	rpm  => 'application/x-rpm',
	text => 'text/plain',
	xls  => 'application/ms-excel',
);

sub init {
	my($self) = @_;

	return 0 if ! $self->SUPER::init();

	$self->{_table} = 'blobs';
	$self->{_prime} = 'id';

	1;
}

sub create {
	my($self, $values) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};

	$values->{seclev} ||= 0;
	if (!$values->{content_type} && $values->{filename}) {
		(my $ext = lc $values->{filename}) =~ s/^.*\.([^.]+)$/$1/s;
		if ($mimetype_overrides{$ext}) {
			$values->{content_type} = $mimetype_overrides{$ext};
		} else {
			my $m = MIME::Types->new();
			$values->{content_type} = $m->mimeTypeOf($values->{filename}) if $m;
		}
	}
	$values->{content_type} ||= 'application/octet-stream';

	my $id = md5_hex($values->{data});

	my $where = "$prime='$id'";

	my $found  = $self->sqlSelect($prime, $table, $where);
	if ($found) {
		$self->sqlDo("UPDATE $self->{'_table'} SET reference_count=(reference_count +1) WHERE id = '$found'");
	} else {
		$values->{$prime} = $id;

		# if the size of the data is greater than the size of the max
		# packet MySQL can accept, let's set it higher before saving the
		# data -- pudge

		my $len = length $values->{data};
		my $var = 'max_allowed_packet';
		my $value;

		my $base = 1024**2;  # 1MB
		if ($len > $base) {
			$value = $self->sqlGetVar($var);
			my $needed = $len + $base;

			if ($value < $needed) {
				return unless $self->sqlSetVar($var, $needed*2);
				my $check = $self->sqlGetVar($var);
				if ($check < $needed) {
					errorLog("Value of $var is $check, should be $needed\n");
					return undef;
				}

				# easily turn off for testing
				my $do_chunk = 1;
				my($size, $data);

				# chunking will be used here because 1. on old
				# 3.x client lib, you cannot set the max packet size
				# larger, and 2. sometimes the MySQL server "goes
				# away" with a lot of data anyway.  although in such
				# cases, we have trouble *getting* the data back,
				# but this is a problem for another day. -- pudge
				if ($do_chunk) {
					# smarter?
					$size = $base >= $value ? $base/2 : $base; 
					$data = $values->{data};
					$values->{data} = substr($data, 0, $size, '');
				}

				$self->sqlInsert($table, $values) or return undef;

				if ($do_chunk) {
					while (length $data) {
						my $chunk = $self->sqlQuote(substr($data, 0, $size, ''));
						my $ok = $self->sqlUpdate($table, {
								-data => "CONCAT(data, $chunk)"
							}, $where
						);

						if (!$ok) { # abort
							$self->sqlDelete($table, $where);
							return undef;
						}
					}
				}

				# the new value is only session-specific anyway,
				# but set it back for good measure
				$self->sqlSetVar($var, $value);

			} else {
				undef $value;
			}
		}

		# true $value means we already saved the data
		unless ($value) {
			$self->sqlInsert($table, $values) or return undef;
		}

		# verify we saved what we think we did
		# (note: even when we cannot retrieve all the data we saved,
		# the MD5() check still works, so the data is all there; maybe
		# some other MySQL setting about getting large amounts of data
		# is giving us problems in the tests -- pudge
		my $md5 = $self->sqlSelect('MD5(data)', $table, $where);
		unless ($md5 eq $id) {
			errorLog("md5:$md5 != id:$id\n");
			$self->sqlDelete($table, $where);
			return undef;
		}
	}

	return $found || $id ;
}

sub delete {
	my($self, $sig) = @_;
	my $sig_q = $self->sqlQuote($sig);
	return $self->sqlUpdate(
		$self->{_table},
		{ -reference_count => "reference_count - 1" },
		"id = $sig_q");
}

sub clean {
	my($self, $sig) = @_;
	return $self->sqlDelete($self->{_table}, "reference_count < 1");
}

sub get {
	my($self, $sig) = @_;
	my $sig_q = $self->sqlQuote($sig);
	return $self->sqlSelectHashref("*", $self->{_table}, "id = $sig_q");
}

sub getFilesForStories {
	my($self) = @_;
	$self->sqlSelectAllHashrefArray('*', 'story_files', '', "ORDER BY stoid,description");
}

sub getFilesForStory {
	my($self, $id) = @_;
	return unless $id;

	# Grandfather in an old-style sid.
	my $stoid;
	my $id_style = $self->_storyidstyle($id);
	if ($id_style eq 'stoid') {
		$stoid = $id;
	} else {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		$stoid = $reader->getStory($id, 'stoid', 1);
		return 0 unless $stoid;
	}

	$self->sqlSelectAllHashrefArray('*', 'story_files',
		"stoid=$stoid",
		"ORDER BY description");
}

sub createFileForStory {
	my($self, $values) = @_;
	return unless $values->{data}
		&& ($values->{sid} || $values->{stoid});

	# Grandfather in an old-style sid.
	if (!$values->{stoid}) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $stoid = $reader->getStory($values->{sid}, 'stoid', 1);
		return unless $stoid;
		$values->{stoid} = $stoid;
	}

	my $content = {
		seclev		=> $values->{seclev},
		filename	=> $values->{filename},
		content_type	=> $values->{content_type},
		data		=> $values->{data},
	};

	my $id = $self->create($content) or return undef;

	my $content_type = $self->get($id, 'content_type');

	my $file_content = {
		stoid		=> $values->{stoid},
		description	=> $values->{description} || $values->{filename} || $content_type,
		isimage		=> ($content_type =~ /^image/) ? 'yes': 'no',
		file_id		=> $id,
	};
	$self->sqlInsert('story_files', $file_content);

	return $self->getLastInsertId;
}

sub deleteStoryFile {
	my($self, $id) = @_;
	my $id_q = $self->sqlQuote($id);
	my $file_id = $self->sqlSelect("file_id",
		"story_files",
		"id = $id_q");
	return undef if !$file_id;
	$self->delete($file_id);
	return $self->sqlDelete("story_files", "id=$id_q");
}

sub _storyidstyle {
	my($self, $id) = @_;
	if ($id =~ /^\d+$/) {
		return "stoid";
	}
	return "sid";
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}

1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Blob - Blob system splace

=head1 SYNOPSIS

	use Slash::Blob;

=head1 DESCRIPTION

This is a port of Tangent's journal system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
