# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::YASS;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION @EXPORT);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'YASS'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getSidsURLs {
	my ($self) = @_;
	$self->sqlSelectAll("sid, value", "story_param", "name='url'");
}

sub create {
	my ($self, $hash) = @_;
	$hash->{'-touched'} = "now()";
	$self->sqlInsert('yass_sites', $hash);
}

sub success {
	my ($self, $id) = @_;
	my %hash;
	$hash{'-touched'} = "now()";
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
	my $q_url = $self->sqlQuote($url);
	my $q_sid = $self->sqlQuote($sid);
	my $return = 1 
		if  $self->sqlSelect('id', 'yass_sites', "sid = $q_sid AND url = $q_url");
	unless ($return) {
		$return = $self->sqlSelect('sid', 'yass_sites', "sid = $q_sid");
	}
	return $return;
}

sub failed {
	my ($self, $id) = @_;
	my %hash;
	$hash{'-touched'} = "now()";
	$hash{-failures} = "failures+1";
	$self->sqlUpdate('yass_sites', \%hash, "id = $id");
}


sub getActive {
	my ($self, $limit, $all) = @_;
	my $failures = getCurrentStatic('yass_failures');
	$failures ||= '14';

	my ($sid, $order, $where);

	my $order;
	if ($limit) {
		$order = "ORDER BY time DESC LIMIT $limit";
	} else {
		$order = "ORDER BY title ASC";
	}

	if($all) {
		$where = "stories.sid = yass_sites.sid",
	} else {
		$where = "stories.sid = yass_sites.sid and failures < $failures",
	}

	my $sites = $self->sqlSelectAllHashrefArray(
		"yass_sites.sid as sid, url, title, id, failures", 
		"yass_sites, stories", 
		$where,
		$order);

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
