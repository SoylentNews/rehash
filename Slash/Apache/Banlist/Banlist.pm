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
		# This is hardcoded text instead of a template because
		# the idea is that the banned script is costing us
		# resources, and we want to get rid of them as cheaply
		# as possible.
		my $bug_off =<<EOT;
<HTML>
<HEAD><TITLE>BANNED!</TITLE></HEAD>
<BODY BGCOLOR="pink">
<H1>Either your network or ip address has been banned
from this site</H1><BR>
due to script flooding that originated
from your network or ip address. If you feel that this
is unwarranted, feel free to include your IP address
(<b>$cur_ip</b>) in the subject of an email, and we will examine why
there is a ban. If you fail to include the IP address (again,
<em>in the Subject!</em>), then
your message will be deleted and ignored. I mean come
on, we're good, we're not psychic.

<p>Since you can't read the FAQ because you're banned, here's the
<a href="/faq/accounts.shtml#ac900">relevant portion</a>:

<h2>Why is my IP banned?</h2> 
<p>&middot; Perhaps you are running some sort of program that loaded thousands of  
Slashdot Pages.  We have limited resources here and are fairly protective of  
them.  We need to make sure that everyone shares.  If your IP loads thousands  
of pages in a day, you will likely be banned.  Please note that many proxy  
servers load large quantities of pages, but we can usually distinguish  
between proxy servers being used by humans, and IPs running software that is  
hammering our servers.<p> 
&middot; Your IP might have been used to perform some sort of denial of service  
attack against Slashdot.  These range from simple programs that just load a  
lot of pages, to programs that attempt to coordinate an avalanche of posts 
in the forums (often through misconfigured "Open Relay" proxy servers).<p> 
&middot; You might be using a proxy server that is also being used by another person  
who did something from the above list. You should have your <b>proxy server  
administrator</b> <a href="mailto:banned@slashdot.org">contact us</a>. <br> 
<br> 
<i><small> Answered by: <a href="mailto:malda@slashdot.org">CmdrTaco</a> <br> 
Last Modified: 3/26/02<br> 
</small></i> <a name="ac1000"></a>  
<h2>How do I get an IP Unbanned?</h2> 
<p>Email <a href="mailto:banned@slashdot.org">banned@slashdot.org</a>. Make  
sure to include the IP in question, and any other pertinent information. If  
you are connecting through a proxy server, you might need to have your proxy  
server's admin contact us instead of you. <br> 
<br> 
<i><small> Answered by: <a href="mailto:malda@slashdot.org">CmdrTaco</a> <br> 
Last Modified: 3/26/02</small></i><i><small><br></small></i> 
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
