# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache;

use strict;
use Apache::ModuleConfig;
use Apache::Constants qw(:common);
use Slash::DB;
use Slash::Utility;
require DynaLoader;
require AutoLoader;
use vars qw($REVISION $VERSION @ISA);

@ISA		= qw(DynaLoader);
$VERSION	= '2.000000';	# v2.0.0
($REVISION)	= ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

bootstrap Slash::Apache $VERSION;

# BENDER: There's nothing wrong with murder, just as long
# as you let Bender whet his beak.

sub SlashVirtualUser ($$$) {
	my($cfg, $params, $user) = @_;
	$cfg->{VirtualUser} = $user;
	$cfg->{slashdb} = Slash::DB->new($user);
	$cfg->{constants} = $cfg->{slashdb}->getSlashConf($user);

	# placeholders ... store extra placeholders in DB?  :)
	for (qw[user form themes template cookie]) {
		$cfg->{$_} = '';
	}

	my $anonymous_coward = $cfg->{slashdb}->getUser(
		$cfg->{constants}{anonymous_coward_uid}
	);

	# Lets just do this once
	my $timezones = $cfg->{slashdb}->getDescriptions('tzcodes');
	$anonymous_coward->{off_set} = $timezones->{ $anonymous_coward->{tzcode} };
	my $dateformats = $cfg->{slashdb}->getDescriptions('datecodes');
	$anonymous_coward->{'format'} = $dateformats->{ $anonymous_coward->{dfid} };

	$cfg->{anonymous_coward} = $anonymous_coward; 
	$cfg->{menus} = $cfg->{slashdb}->getMenus();
	$cfg->{slashdb}->{_dbh}->disconnect;
}

sub IndexHandler {
	my($r) = @_;

	my $constants = getCurrentStatic();
	my $uri = $r->uri;
	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	if ($uri eq '/') {
		my $filename  = $r->filename;
		my $basedir   = $constants->{basedir};

		# cookie data will begin with word char or %
		if ($r->header_in('Cookie') =~ /\b(?:user)=[%\w]/) {
			$r->uri('/index.pl');
			$r->filename("$basedir/index.pl");
			return OK;
		} else {
			$r->uri('/index.shtml');
			$r->filename("$basedir/index.shtml");
			writeLog('shtml');
			return OK;
		}
	}
	
	return DECLINED;
}

sub DESTROY { }


1;

__END__

=head1 NAME

Slash::Apache - Apache Specific handler for Slash

=head1 SYNOPSIS

  use Slash::Apache;

=head1 DESCRIPTION

This is what creates the SlashVirtualUser command for us
in the httpd.conf file.

=head1 SEE ALSO

Slash(3).

=cut
