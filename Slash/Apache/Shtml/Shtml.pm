# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Apache::Shtml;

use strict;
use Apache;
use Apache::Constants qw(:common);
use Apache::Request ();
use Slash::Apache ();
use Slash::Utility;

use vars qw($VERSION @ISA);
@ISA = qw(DynaLoader);
$VERSION = '2.005';
bootstrap Slash::Apache::Shtml $VERSION;

# Of course renaming requires editing a .conf file (see
# bin/install-slashsite PerlTransHandler).
sub handler {
	my($r) = @_;

	return DECLINED unless $r->is_initial_req;

	Apache->request($r);
	my $uri = $r->uri;

	# Only .shtml URLs are processed by this handler.
	return DECLINED unless $uri =~ m{\.shtml(\?|$)};

	# And right now, only /faq/ is processed by this handler.
	return DECLINED unless $uri =~ m{^/faq};

	my $constants = getCurrentStatic();
	$r->args("uri=$uri");
	$r->uri('/shtml.pl');
	$r->filename("$constants->{basedir}/shtml.pl");
	return OK;
}

sub DESTROY { }

1;

