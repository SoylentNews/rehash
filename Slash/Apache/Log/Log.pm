# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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
	my $constants = getCurrentStatic();
	return OK if -e "$constants->{datadir}/dboff";
	return unless $r->status == 200;

	# Notes has a bug (still in apache 1.3.17 at
	# last look). Apache's directory sub handler
	# is not copying notes. Bad Apache!
	# -Brian
	my $uri = $r->uri;
	my $dat = $r->err_header_out('SLASH_LOG_DATA');

	# Added this so that small sites would not have admin logins 
	# recorded in their stats. -Brian

	# so it will still log it if the admin DOES request
	# to admin.pl?  i thought you wanted it to NOT log
	# requests to admin.pl?  should the !~ be =~ ?
	# or am i just not thinking clearly? -- pudge

	if (!$constants->{log_admin} && $uri !~ /admin\.pl/ ) {
		return OK if getCurrentUser('is_admin');
	}

	createLog($uri, $dat);
	return OK;
}

# Rob asked for this, keeping this at the end means
# we can turn it off easily enough (and it won't happen
# during page stuff
sub UserLog {
	my($r) = @_;

	my $user = getCurrentUser();
	return if !$user || !$user->{uid} || $user->{is_anon};

	my $user_update = undef;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	if ($constants->{subscribe}
		&& ($user->{is_subscriber} || !$constants->{subscribe_hits_only})
	) {
		$user_update = { -hits => 'hits+1' };
		my $subscribe = getObject('Slash::Subscribe');
		my $buying = 0;
		if ($subscribe && $subscribe->buyingThisPage($r)) {
			$user_update->{-hits_bought} = 'hits_bought+1';
			$buying = 1;
		}
		my @gmt = gmtime;
		my $today = sprintf("%04d%02d%02d",
			$gmt[5]+1900, $gmt[4]+1, $gmt[3]);
		if ($today eq substr($user->{lastclick}, 0, 8)) {
			# User may or may not be a subscriber, and may or may not
			# be buying this page.  The day has not rolled over.
			# Increment hits_bought_today iff they are buying this page.
			$user_update->{-hits_bought_today} = 'hits_bought_today+1'
				if $buying;
		} else {
			# User may or may not be a subscriber, and may or may not
			# be buying this page.  The day has rolled over since their
			# last click.  Set hits_bought_today to 0 if they are not
			# buying this page, or 1 if they are.  Note that we do not
			# want to set it to the empty string, as that would delete
			# the param row.
			$user_update->{hits_bought_today} = $buying ? 1 : 0;
		}
	}
	if ($constants->{admin_check_clearpass}
		&&  $user->{state}{admin_clearpass_thisclick}
		&& !$user->{admin_clearpass}) {
		# This could be any value as long as it's true.
		$user_update->{admin_clearpass} = join(" ",
			$r->connection->remote_ip, scalar(gmtime));
	}
	$slashdb->setUser($user->{uid}, $user_update) if $user_update;

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
