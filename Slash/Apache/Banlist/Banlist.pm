# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::Banlist;

use strict;
use Apache::Constants qw(:common);
use Digest::MD5 'md5_hex';

use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;

use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler {
	my($r) = @_;

	return DECLINED unless $r->is_main;

	# Ok, this will make it so that we can reliably use Apache->request
	Apache->request($r);
	my $cur_ip = $r->connection->remote_ip;
	my $cur_ipid = md5_hex($cur_ip);
	my $cur_subnet = $cur_ip;
	$cur_subnet =~ s/^(\d+\.\d+\.\d+)\.\d+$/$1.0/;
	$cur_subnet = md5_hex($cur_subnet);

	my $slashdb = getCurrentDB();
	my $reader_user = $slashdb->getDB('reader');

	my $reader = getObject('Slash::DB', { virtual_user => $reader_user });
	$reader->sqlConnect();

	my $is_rss = $r->uri =~ m{(
		\.(?:xml|rss|rdf)$
			|
		content_type=rss
	)}x;  # also check for content_type in POST?

	# check for ban
	my $banlist = $reader->getBanList();
	if ($banlist->{$cur_ipid} || $banlist->{$cur_subnet}) {
		return _send_rss($r, 'ban') if $is_rss;

		$r->custom_response(FORBIDDEN,
			slashDisplay('bannedtext_ipid',
				{ ip => $cur_ip },
				{ Return => 1   }
			)
		);
		return FORBIDDEN;
	}

	# check for RSS abuse
	my $rsslist = $reader->getNorssList();
	if ($is_rss && ($rsslist->{$cur_ipid} || $rsslist->{$cur_subnet})) {
		return _send_rss($r, 'abuse');
	}

	return OK;
}


sub _send_rss {
	my($r, $type) = @_;
	$r->content_type('text/xml');
	$r->status(202);
	$r->send_http_header;
	$r->print(_get_rss_msg($type));
	return DONE;
}

{
# templates don't work with Slash::XML right now,
# and redirecting will cause *more* traffic than
# just spitting it out here; so cache it in $RSS_*
my(%RSS);

sub _get_rss_msg {
	my($type) = @_;
	$type ||= 'abuse';

	return $RSS{$type} if exists $RSS{$type};

	# template puts data in $items
	my $items = [];
	slashDisplay('bannedtext_rss', {
		items	=> $items,
		type	=> $type,
	}, { Return => 1 });

	return $RSS{$type} = xmlDisplay(rss => {
		rdfitemdesc => 1,
		items => $items,
	}, { Return => 1 } );
}

}

sub DESTROY { }

1;

__END__

=head1 NAME

Slash::Apache::Banlist- Handles user banning via ipid 

=head1 SYNOPSIS

	use Slash::Apache::Banlist;

=head1 DESCRIPTION

No method are provided. Basically this handles comparing
md5 hash of a given IP and checks the banned hashref for 
the existence of the key that is the current ipid 

=head1 SEE ALSO

Slash(3), Slash::Apache(3).

=cut
