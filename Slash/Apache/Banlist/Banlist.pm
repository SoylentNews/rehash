# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# This handler is called in the fourth Apache phase, access control.

package Slash::Apache::Banlist;

use strict;
use utf8;
use Apache2::Const;
use Apache2::Connection;
require APR::SockAddr;

use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;

our $VERSION = $Slash::Constants::VERSION;
use APR::SockAddr ();
sub handler {
	my($r) = @_;

	return DECLINED unless !$r->main;

	$Slash::Apache::User::request_start_time ||= Time::HiRes::time;

	# Ok, this will make it so that we can reliably use Apache->request
	Apache2::RequestUtil->request($r);

	# Get some information about the IP this request is coming from.
	my $hostip = $r->connection->remote_addr->ip_get;
	my($cur_ip, $cur_subnet) = get_srcids({ ip => $hostip },
		{ no_md5 => 1,	return_only => [qw( ip subnet )] });
	my($cur_srcid_ip, $cur_srcid_subnet) = get_srcids({ ip => $hostip },
		{ 		return_only => [qw( ip subnet )] });
#print STDERR scalar(localtime) . " hostip='$hostip' cur_ip='$cur_ip' cur_subnet='$cur_subnet' cur_srcid_ip='$cur_srcid_ip' cur_srcid_subnet='$cur_srcid_subnet'\n";

	# Set up DB objects.
	my $slashdb = getCurrentDB();
	my $reader_user = $slashdb->getDB('reader');
	my $reader = getObject('Slash::DB', { virtual_user => $reader_user });
	$reader->sqlConnect;

	# Check what kind of access this is.
	
	my($is_rss, $is_palm, $feed_type) = _check_rss_and_palm($r);

	# Abort this Apache request if this IP address is outright banned.

	my $banlist = $reader->getBanList;
#use Data::Dumper; $Data::Dumper::Sortkeys=1;
#print STDERR "cur_srcid_ip='$cur_srcid_ip' cur_srcid_subnet='$cur_srcid_subnet' banlist: " . Dumper($banlist);
	if ($banlist->{$cur_srcid_ip} || $banlist->{$cur_srcid_subnet}) {
		_create_banned_user($hostip);
		# Send a special "you are banned" page if the user is
		# hitting RSS.
		return _send_rss($r, 'ban', $cur_srcid_ip, $feed_type) if $is_rss;
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
	if ($is_rss) {
		my $rsslist = $reader->getNorssList;
		if ($rsslist->{$cur_srcid_ip} || $rsslist->{$cur_srcid_subnet}) {
			_create_banned_user($hostip);
			return _send_rss($r, 'abuse', $cur_srcid_ip, $feed_type);
		}
	}

	# Send a special "Palm banned" page if this IP addresss is banned
	# from reading Palm pages.
	if ($is_palm) {
		my $palmlist = $reader->getNopalmList;
		if ($palmlist->{$cur_srcid_ip} || $palmlist->{$cur_subnet}) {
			_create_banned_user($hostip);
			$r->custom_response(FORBIDDEN,
				slashDisplay('bannedtext_palm',
					{ ip => $cur_ip },
					{ Return => 1   }
				)
			);
			return FORBIDDEN;
		}
	}

	# The IP address is not banned and can proceed.
	return OK;
}

# Now we need to create a user hashref for that global
# current user, so these fields of accesslog get written
# correctly when we log this attempted hit.  We do this
# dummy hashref with the bare minimum of values that we need,
# instead of going through prepareUser(), because this is
# much, much faster.
sub _create_banned_user {
	my($hostip) = @_;
	my($ipid, $subnetid) = get_ipids($hostip);
	my $user = {
		uid		=> getCurrentStatic('anonymous_coward_uid'),
		ipid		=> $ipid,
		subnetid	=> $subnetid,
	};
	createCurrentUser($user);
}


sub _check_rss_and_palm {
	my($r) = @_;
	my $is_rss = $r->uri =~ m{(
		\.(xml|rss|rdf|atom)$
			|
		content_type=(rss|atom)
	)}x;
	my $feed_type = $1 || $2 || 'rss';
	$feed_type = 'rss' unless $feed_type eq 'atom';

	# XXX Should we also check for content_type in POST?
	my $is_palm = $r->uri =~ /^\/palm/;
	return($is_rss, $is_palm, $feed_type);
}

sub _send_rss {
	my($r, $type, $srcid_ip, $feed_type) = @_;
	http_send({
		content_type	=> 'text/xml',
		status		=> 202,
		content		=> _get_rss_msg($type, $srcid_ip, $feed_type),
	});

	return DONE;
}

{
# templates don't work with Slash::XML right now,
# and redirecting will cause *more* traffic than
# just spitting it out here; so cache it in $RSS_*
# XXX that really should be a cache that eventually expires
my(%RSS);

sub _get_rss_msg {
	my($type, $srcid_ip, $feed_type) = @_;
	$type ||= 'abuse';
	$srcid_ip ||= '(unknown)';
	$feed_type ||= 'rss';

	return $RSS{$type}{$srcid_ip} if exists $RSS{$type}{$srcid_ip};

	# template puts data in $items
	my $items = [];
	slashDisplay('bannedtext_rss', {
		items		=> $items,
		type		=> $type,
		srcid_ip	=> $srcid_ip,
	}, { Return => 1 });

	$RSS{$type}{$srcid_ip} = xmlDisplay($feed_type => {
		rdfitemdesc	=> 1,
		items		=> $items,
	}, { Return => 1 } );
	if (!$RSS{$type}{$srcid_ip}) {
		# Just a quick sanity error check.
		errorLog("xmlDisplay for type='$type' srcid_ip='$srcid_ip' empty");
	}
	return $RSS{$type}{$srcid_ip};
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
