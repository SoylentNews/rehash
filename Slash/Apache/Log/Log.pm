# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::Log;

use strict;
use Slash::Utility;
use Apache::Constants qw(:common);
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# AMY: Leela's gonna kill me.
# BENDER: Naw, she'll probably have me do it.

sub handler {
	my($r) = @_;
	my $slashdb = getCurrentDB();

	# Notes has a bug (still in apache 1.3.17 at
	# last look). Apache's directory sub handler
	# is not copying notes. Bad Apache!
	# -Brian
	my $uri = $r->uri;
	my $dat = $r->err_header_out('SLASH_LOG_DATA');
	if ($uri eq '/') {
		$slashdb->createAccessLog('index', $dat);
	} elsif ($uri =~ /\.pl$/) {
		$uri =~ s/^\/(.*)\.pl$/$1/;
		$slashdb->createAccessLog($uri, $dat);
	} elsif ($uri =~ /\.shtml$/) {
		$uri =~ s/^\/(.*)\.shtml$/$1/;
		$slashdb->createAccessLog($uri, $dat);
	} elsif ($uri =~ /\.html$/) {
		$uri =~ s/^\/(.*)\.html$/$1/;
		$slashdb->createAccessLog($uri, $dat);
	}

	return OK;
}

sub DESTROY { }

1;

__END__

=head1 NAME

Slash::Apache::Log - Handles logging for slashdot

=head1 SYNOPSIS

  use Slash::Apache::Log;

=head1 DESCRIPTION

No method are provided. Basically this handles grabbing the
data out of the Apache process and logging it to the
database. 

=head1 SEE ALSO

Slash(3), Slash::Apache(3).

=cut
