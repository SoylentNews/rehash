# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Apache::Log;

use strict;
use Slash::Utility;
use Apache::Constants qw(:common);

our $VERSION = $Slash::Constants::VERSION;

# AMY: Leela's gonna kill me.
# BENDER: Naw, she'll probably have me do it.

# Note regarding Apache::DBI:
# Slash does not use Apache::DBI (it's just an extra, unnecessary,
# layer of dbh caching).  However, some sites may use it, perhaps for
# other database-backed projects on the same web server.  Apache::DBI
# pushes a PerlCleanupHandler with every created dbh, to roll back
# any open transactions.  The docs for Apache.pm say a handler added
# with push_handlers will be called "before any configured handlers,"
# i.e. before Slash's PerlCleanupHandler, i.e. before the functions below.
# Since createLog and setUser don't leave any transactions open, this
# should not be a problem.

#
# This is the first PerlCleanupHandler in each site's .conf file
# (as written by install-slashsite).  This handler writes to the
# accesslog table.
#

sub handler {
	my($r) = @_;
	return OK unless dbAvailable("write_accesslog");
	my $constants = getCurrentStatic();

	# Notes has a bug (still in apache 1.3.17 at
	# last look). Apache's directory sub handler
	# is not copying notes. Bad Apache!
	# -Brian
	my $uri = $r->uri;
	my $dat = $r->err_header_out('SLASH_LOG_DATA');

	# There used to be some (broken) logic here involving the
	# log_admin var, but that's been moved to createLog().

	createLog($uri, $dat, $r->status);

	return OK;
}

#
# This is the second PerlCleanupHandler in each site's .conf file
# (as written by install-slashsite).  This handler writes new
# values into the users_* tables, and possibly updates stats as
# well.  Note that this should not be called for image hits, since
# we don't think of GIFs, PNGs and JPEGs as "hits" (and if we
# count them for subscribers we will do them a disservice).
#

sub UserLog {
	my($r) = @_;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	return if !$user || !$user->{uid} || $user->{is_anon};

	my $user_update = undef;
	my $slashdb = getCurrentDB();

	# First check to see if this is an admin who sent a password
	# in cleartext.  If so and if we want to flag that, flag it
	# and continue.  If not, then check to see if this is an image we've just
	# served, in which case we don't write a log entry.

	if ($constants->{admin_check_clearpass}
		&&  $user->{state}{admin_clearpass_thisclick}
		&& !$user->{admin_clearpass}) {
		# This could be any value as long as it's true.
		$user_update->{admin_clearpass} = join(" ",
			$r->connection->remote_ip, scalar(gmtime));
	}

	my($op) = getOpAndDatFromStatusAndURI($r->status, $r->uri);
	# Short-circuit so we don't log image requests -- unless
	# this is an admin who just sent a password in the clear.
	# There are other less-important things that might get updated
	# but none of them matters enough to continue processing.
	if ($op eq 'image' && !$user_update->{admin_clearpass}) {
#		print STDERR scalar(gmtime) . " $$ UserLog short-circuit image\n";
		return ;
	}

	# For the below logic, note that if we're on an image hit,
	# page_buying will be false.
	# Err, and that doesn't matter since if we're on an image,
	# we already returned.  So I'm not sure why I wrote that.
	if ($constants->{subscribe}
		&& ($user->{is_subscriber} || !$constants->{subscribe_hits_only})
	) {
		if ($op ne 'image') {
			$user_update = { -hits => 'hits+1' };
			$user_update->{-hits_bought} = 'hits_bought+1'
				if $user->{state}{page_buying};
		}
		my @gmt = gmtime;
		my $today = sprintf("%04d%02d%02d",
			$gmt[5]+1900, $gmt[4]+1, $gmt[3]);
		# See the code near the end of MySQL.pm _getUser_do_selects()
		# which forces $user->{lastclick} to be in the numeric format
		# originally used by the MySQL 4.0 TIMESTAMP column type.
		if ($today eq substr($user->{lastclick}, 0, 8)) {
			# User may or may not be a subscriber, and may or may not
			# be buying this page.  The day has not rolled over.
			# Increment hits_bought_today iff they are buying this page.
			$user_update->{-hits_bought_today} = 'hits_bought_today+1'
				if $user->{state}{page_buying};
		} else {
			# User may or may not be a subscriber, and may or may not
			# be buying this page.  The day has rolled over since their
			# last click.  Set hits_bought_today to 0 if they are not
			# buying this page, or 1 if they are.  Note that we do not
			# want to set it to the empty string, as that would delete
			# the param row.
			$user_update->{hits_bought_today} = $user->{state}{page_buying} ? 1 : 0;
			if ($user->{hits_bought_today} && !$user->{is_admin}) {
				my $day = join("-",
					$user->{lastclick} =~ /^(\d{4})(\d{2})(\d{2})/);
				my $statsSave = getObject('Slash::Stats::Writer', '',
					{ day => $day });
				if ($statsSave) {
					# The user bought pages, one or more days ago, and
					# we are now zeroing out that count, but we want
					# its old value for our stats.
					$statsSave->addStatDaily("subscribe_hits_bought",
						$user->{hits_bought_today});
				}
			}
		}
		if ($user->{state}{page_buying}
			&& $user->{hits_bought} == $user->{hits_paidfor}-1
			and my $statsSave = getObject('Slash::Stats::Writer')) {
			$statsSave->addStatDaily("subscribe_runout", 1);
		}
	}
	if ($user_update && keys(%$user_update)) {
		if ($constants->{memcached_debug}) {
			print STDERR scalar(gmtime) . " $$ mcd UserLog id=$user->{uid} setUser: upd '$user_update' keys '" . join(" ", sort keys %$user_update) . "'\n";
		}
		$slashdb->setUser($user->{uid}, $user_update);
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
