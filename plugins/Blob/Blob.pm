# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
my %mimetypes = (
	jpeg => 'image/jpeg',
	jpg => 'image/jpeg',
	gif => 'image/gif',
	png => 'image/png',
	tiff => 'image/tiff',
	tif => 'image/tiff',
	ps => 'application/postscript',
	eps => 'application/postscript',
	zip => 'application/zip',
	doc => 'application/msword',
	pdf => 'application/pdf',
	gz => 'application/x-gzip',
	bz2 => 'application/x-bzip2',
	rpm => 'application/x-rpm',
	mp3 => 'audio/mp3',
	ra => 'audio/x-realaudio',
	html => 'text/html',
	htm => 'text/html',
	txt => 'text/plain',
	text => 'text/plain',
	xml => 'text/xml',
	rtf => 'text/rtf',
);

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Blob'};

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
		my $filename = lc($values->{filename});
		$filename =~ s/.*\.(.*)$/$1/g;
		$values->{content_type} = $mimetypes{$filename};
	}
	delete($values->{filename});
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
	my ($self, $sig) = @_;

	$self->sqlDo("UPDATE $self->{'_table'} SET reference_count=(reference_count -1) WHERE id = '$sig'");
}

sub clean {
	my ($self, $sig) = @_;

	$self->sqlDo("DELETE FROM $self->{'_table'} WHERE reference_count < 1");
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
