# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::Banlist;

use strict;
use Slash::Utility;
use Slash::Display;
use Digest::MD5 'md5_hex';
use Apache::Constants qw(:common);
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
	$slashdb->sqlConnect();
	
	my $banlist = $slashdb->getBanList();

	if ($banlist->{$cur_ipid} || $banlist->{$cur_subnet}) {
		$r->custom_response(FORBIDDEN,
			slashDisplay('bannedtext_ipid', { ip => $cur_ip },
				{ Return => 1} )
		);
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
