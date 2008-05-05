# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::YASS;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our $VERSION = $Slash::Constants::VERSION;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'YASS'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getSidsURLs {
	my ($self) = @_;
	# This was originally written to return an arrayref of
	# arrayrefs of two values: sid, url.  Since the stories
	# tables converted to stoids, this became a little more
	# complicated, but that's OK.
	my $stoid_value_hr = $self->sqlSelectAllHashref(
		'stoid',
		'stoid, value',
		'story_param',
		"name='url'");
	return [ ] if !$stoid_value_hr || !%$stoid_value_hr;
	my @stoids = sort keys %$stoid_value_hr;
	my $stoids_in = join(',', @stoids);
	my $sid_stoid_ar = $self->sqlSelectAll('sid, stoid', 'stories',
		"stoid IN ($stoids_in)");
	# The duples are [sid,stoid] now; replace them in place with
	# [sid,value].
	for my $duple (@$sid_stoid_ar) {
		$duple->[1] = $stoid_value_hr->{ $duple->[1] }{value} || '';
	}
	return $sid_stoid_ar;
}

sub create {
	my ($self, $hash) = @_;
	$hash->{'-touched'} = "NOW()";
	$self->sqlInsert('yass_sites', $hash);
}

sub success {
	my ($self, $id) = @_;
	my %hash;
	$hash{'-touched'} = "NOW()";
	$hash{failures} = "0";
	$self->sqlUpdate('yass_sites', \%hash, "id = $id");
}

sub setURL {
	my ($self, $id, $url, $rdf) = @_;
	my %hash;
	$hash{url} = $url;
	$hash{rdf} = $rdf;
	$self->sqlUpdate('yass_sites', \%hash, "id = $id");
}

sub exists {
	my ($self, $sid, $url) = @_;
	my $url_q = $self->sqlQuote($url);
	my $sid_q = $self->sqlQuote($sid);
	my $return = $self->sqlSelect('id', 'yass_sites', "sid = $sid_q AND url = $url_q")
		|| $self->sqlSelect('id', 'yass_sites', "sid = $sid_q")
		|| 0;
	return $return;
}

sub failed {
	my ($self, $id) = @_;
	my %hash;
	$hash{'-touched'} = "NOW()";
	$hash{-failures} = "failures+1";
	$self->sqlUpdate('yass_sites', \%hash, "id = $id");
}


sub getActive {
	my ($self, $limit, $all) = @_;
	my $failures = getCurrentStatic('yass_failures');
	$failures ||= '14';

	my ($sid, $order, $where);

	if ($limit) {
		$order = "ORDER BY time DESC LIMIT $limit";
	} else {
		$order = "ORDER BY title ASC";
	}

	$where = 'stories.sid = yass_sites.sid AND stories.stoid=story_text.stoid';
	$where .= " AND failures < $failures" if !$all;

	my $sites = $self->sqlSelectAllHashrefArray(
		"yass_sites.sid AS sid, url, title, id, failures", 
		"yass_sites, stories, story_text", 
		$where,
		$order) || [];

	return $sites;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::YASS - YASS system splace

=head1 SYNOPSIS

	use Slash::YASS;

=head1 DESCRIPTION

This is YASS, and just how useful is this to you? Its 
a site link system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
