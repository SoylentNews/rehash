# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::Banlist;

use strict;
use Slash::Utility;
use Digest::MD5 'md5_hex';
use Apache::Constants qw(:common);
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler {
	my($r) = @_;

	$r = Apache->request;

	return DECLINED unless $r->is_main;

	# Ok, this will make it so that we can reliably use Apache->request
	Apache->request($r);
	my $cur_ip = $r->connection->remote_ip;
	my $cur_ipid = md5_hex($cur_ip);
	my $cur_subnet = $cur_ip;
	$cur_subnet =~ s/^(\d+\.\d+\.\d+)\.\d+$/$1.0/;
	$cur_subnet = md5_hex($cur_subnet);

	my $slashdb = getCurrentDB();
	$slashdb->sqlConnect();
	
	my $banlist = $slashdb->getBanList();

	if ($banlist->{$cur_ipid} || $banlist->{$cur_subnet}) {
		my $bug_off =<<EOT;
<HTML>
<HEAD><TITLE>BANNED!</TITLE></HEAD>
<BODY BGCOLOR="pink">
<H1>Either your network or ip address has been banned
from this site</H1><BR>
due to script flooding that originated
from your network or ip address. If you feel that this
is unwarranted, feel free to include your IP address
(<b>$cur_ip</b>) in an email, and we will examine why
there is a ban. If you fail to include the IP address,
your message will be deleted and ignored. I mean come
on, we're good, we're not psychic.
</BODY>
</HTML>
EOT
		$r->custom_response(FORBIDDEN, $bug_off); 
		return FORBIDDEN;
	}

	return OK;
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
