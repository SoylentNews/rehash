# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Blob;

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;
use Digest::MD5 'md5_hex';

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Mime/Type hash (couldn't find a module that I liked that would do this -Brian
# there are plenty of other methods out there, this needs to be replaced -- pudge
my %mimetypes = (
	jpeg => 'image/jpeg',
	jpg  => 'image/jpeg',
	gif  => 'image/gif',
	png  => 'image/png',
	tiff => 'image/tiff',
	tif  => 'image/tiff',
	ps   => 'application/postscript',
	eps  => 'application/postscript',
	zip  => 'application/zip',
	doc  => 'application/msword',
	xls  => 'application/ms-excel',
	pdf  => 'application/pdf',
	gz   => 'application/x-gzip',
	bz2  => 'application/x-bzip2',
	rpm  => 'application/x-rpm',
	mp3  => 'audio/mp3',
	ra   => 'audio/x-realaudio',
	html => 'text/html',
	htm  => 'text/html',
	txt  => 'text/plain',
	text => 'text/plain',
	xml  => 'text/xml',
	rtf  => 'text/rtf',
);

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Blob'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;
	$self->{'_table'} = "blobs";
	$self->{'_prime'} = "id";

	return $self;
}

sub create {
	my($self, $values) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};

	$values->{seclev} ||= 0;
	# Couldn't find a module that did this
	if (!$values->{content_type} && $values->{filename}) {
		(my $ext = lc $values->{filename}) =~ s/^.*\.([^.]+)$/$1/s;
		$values->{content_type} = $mimetypes{$ext};
	}
	$values->{content_type} ||= 'application/octet-stream';

	my $id = md5_hex($values->{data});

	my $where = "$prime='$id'";

	my $found  = $self->sqlSelect($prime, $table, $where);
	if ($found) {
		$self->sqlDo("UPDATE $self->{'_table'} SET reference_count=(reference_count +1) WHERE id = '$found'");
	} else {
		$values->{$prime} = $id;
		$self->sqlInsert($table, $values);
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

	my $id = $self->create($content);
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
