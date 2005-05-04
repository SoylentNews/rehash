# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# This handler is called in the fourth Apache phase, access control.

package Slash::Apache::Banlist;

use strict;
use Apache::Constants qw(:common);

use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;

use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler {
	my($r) = @_;

	return DECLINED unless $r->is_main;

	$Slash::Apache::User::request_start_time ||= Time::HiRes::time;

	# Ok, this will make it so that we can reliably use Apache->request

	Apache->request($r);

	# Get some information about the IP this request is coming from.

	my $hostip = $r->connection->remote_ip;
	my($cur_ip, $cur_subnet) = get_srcids({ ip => $hostip },
		{ no_md5 => 1,	return_only => [qw( ip subnet )] });
	my($cur_ipid, $cur_subnetid) = get_srcids({ ip => $hostip },
		{ 		return_only => [qw( ip subnet )] });

	# Set up DB objects.

	my $slashdb = getCurrentDB();
	my $reader_user = $slashdb->getDB('reader');
	my $reader = getObject('Slash::DB', { virtual_user => $reader_user });
	$reader->sqlConnect;

	# Check what kind of access this is.
	
	my($is_rss, $is_palm) = _check_rss_and_palm($r);

	# Abort this Apache request if this IP address is outright banned.

	my $banlist = $reader->getBanList;
#use Data::Dumper; $Data::Dumper::Sortkeys=1;
#print STDERR "cur_ipid='$cur_ipid' cur_subnetid='$cur_subnetid' banlist: " . Dumper($banlist);
	if ($banlist->{$cur_ipid} || $banlist->{$cur_subnetid}) {
		# Send a special "you are banned" page if the user is
		# hitting RSS.
		return _send_rss($r, 'ban', $cur_ipid) if $is_rss;
		# Send our usual "you are banned" page, whether the user
		# is on palm or not.  It's mostly text so palm users
		# should not have a problem with it.
		$r->custom_response(FORBIDDEN,
			slashDisplay('bannedtext_ipid',
				{ ip => $cur_ip },
				{ Return => 1   }
			)
		);
		return FORBIDDEN;
	}

	# Send a special "RSS banned" page if this IP address is banned
	# from reading RSS.

	my $rsslist = $reader->getNorssList;
	if ($is_rss && ($rsslist->{$cur_ipid} || $rsslist->{$cur_subnetid})) {
		return _send_rss($r, 'abuse', $cur_ipid);
	}

	# Send a special "Palm banned" page if this IP addresss is banned
	# from reading Palm pages.

	my $palmlist = $reader->getNopalmList;
	if ($is_palm && ($palmlist->{$cur_ipid} || $palmlist->{$cur_subnet})) {
		$r->custom_response(FORBIDDEN,
			slashDisplay('bannedtext_palm',
				{ ip => $cur_ip },
				{ Return => 1   }
			)
		);
		return FORBIDDEN;
	}

	# The IP address is not banned and can proceed.

	return OK;
}

sub _check_rss_and_palm {
	my($r) = @_;
	my $is_rss = $r->uri =~ m{(
		\.(?:xml|rss|rdf)$
			|
		content_type=rss
	)}x;
	# XXX Should we also check for content_type in POST?
	my $is_palm = $r->uri =~ /^\/palm/;
	return ($is_rss, $is_palm);
}

sub _send_rss {
	my($r, $type, $ipid) = @_;
	http_send({
		content_type	=> 'text/xml',
		status		=> 202,
		content		=> _get_rss_msg($type, $ipid),
	});

	return DONE;
}

{
# templates don't work with Slash::XML right now,
# and redirecting will cause *more* traffic than
# just spitting it out here; so cache it in $RSS_*
my(%RSS);

sub _get_rss_msg {
	my($type, $ipid) = @_;
	$type ||= 'abuse';
	$ipid ||= '(unknown)';

	return $RSS{$type}{$ipid} if exists $RSS{$type}{$ipid};

	# template puts data in $items
	my $items = [];
	slashDisplay('bannedtext_rss', {
		items	=> $items,
		type	=> $type,
		ipid	=> $ipid,
	}, { Return => 1 });

	return $RSS{$type}{$ipid} = xmlDisplay(rss => {
		rdfitemdesc	=> 1,
		items		=> $items,
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
