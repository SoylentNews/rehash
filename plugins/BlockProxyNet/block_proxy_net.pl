#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Socket qw( inet_aton inet_ntoa );
use LWP::UserAgent;
use Time::HiRes;
use Slash::Utility;

use Slash::Constants ':slashd';

use vars qw( $VERSION %task $me $task_exit_flag );

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Update once a day, in the middle of the night.
$task{$me}{timespec} = '10 8 * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $srn_ar = $slashdb->sqlSelectAllHashrefArray('*', 'bpn_sources',
		"active='yes'", 'ORDER BY name');
	return "" unless $srn_ar && @$srn_ar;

	my($old, $new) = (0, 0);
	for my $srn_hr (@$srn_ar) {

		my $data = load_from_source($srn_hr->{source});
		last if $task_exit_flag;
		my $ip_ar = extract_ips($data, $srn_hr->{regex});
		last if $task_exit_flag;
		my($o, $n) = set_ips($slashdb, $ip_ar, $srn_hr->{name}, $srn_hr->{al2name});
		$old += $o; $new += $n;

	}

	return "old: $old new: $new";
};

sub load_from_source {
	my($source) = @_;
	my $data = "";
	if ($source =~ m{^/}) {
		# If it starts with /, assume it's an absolute filename.
		my $fh;
		if (!open($fh, $source)) {
			slashdLog("could not open file '$source', $!");
			return "";
		}
		while (my $line = <$fh>) {
			$data .= $line;
		}
		close $fh;
		return $data;
	}
	my $uri = URI->new($source);
	if (!$uri) {
		slashdLog("could not create URI from '$source'");
		return "";
	}
	my $ua = LWP::UserAgent->new();
	my $response = $ua->get($uri);
	if (!$response->is_success) {
		slashdLog("URI '$source' returned an error: '" . $response->message() . "'");
		return "";
	}
	$data = $response->content();
	if (!$data) {
		slashdLog("URI '$source' returned no content");
		return "";
	}
	return $data;
}

sub extract_ips {
	my($data, $regex) = @_;
	return [ ] if !$data || !$regex;
	my %ip = ( );
	my @extracts = $data =~ /$regex/g;
	for my $ip (@extracts) {
		return [ ] if $task_exit_flag;
		# Sanity check, since we can never fully trust data from
		# an outside source.  Convert it to a 32-bit int, then
		# back to the text string.
		next unless $ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
		my $ip =
			inet_ntoa(
			pack "N",
			unpack "N",
			inet_aton(
			$ip ));
		# On syntax errors, the above will return '0.0.0.0'.
		next if $ip =~ /^0/;
		# Don't block internal networks (RFC 1918).
		next if $ip =~ /^(127|10|192\.168|176\.(1[6-9]|2[0-9]|3[0-1]))\./;
		$ip{$ip} = 1;
		Time::HiRes::sleep(0.02);
	}
	return [ sort keys %ip ];
}

sub set_ips {
	my($slashdb, $ip_ar, $srnname, $al2name) = @_;
	return (0, 0) if !$ip_ar || !@$ip_ar;
	my $al2types = $slashdb->getAL2Types;
	return (0, 0) if !$al2types->{$al2name};

	# Only set and log IPs which are new (otherwise we'd add
	# unnecessary lines to al2_log every day).
	my $constants = getCurrentStatic();
	my $adminuid = $constants->{bpn_adminuid} || 0;
	my($old, $new) = (0, 0);
	IP: for my $ip (@$ip_ar) {
		my $srcid = convert_srcid(ip => $ip);
		my $hr = $slashdb->getAL2($srcid);
		# If we've blocked this one already, skip it.
		if ($hr->{$al2name}) {
			++$old;
			next IP;
		}
		# If this IP is trusted or marked as a valid proxy,
		# skip it.
		next IP if $hr->{trusted} || $hr->{proxy};
		# It's new, block it.
		my $comment = "BPN $srnname $ip";
		my $is_new = $slashdb->setAL2($srcid,
			{ $al2name, 1, comment => $comment },
			{ adminuid => $adminuid });
		if ($is_new) { ++$new }
		        else { ++$old }
		Time::HiRes::sleep(0.02);
	}
	return($old, $new);
}

1;

