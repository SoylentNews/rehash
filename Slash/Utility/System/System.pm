# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Utility::System;

=head1 NAME

Slash::Utility::System - SHORT DESCRIPTION for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	# do not use this module directly

=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Email::Valid;
use File::Basename;
use File::Path;
use File::Spec::Functions;
use IPC::Open3 'open3';
use Mail::Sendmail;
use POSIX 'WNOHANG';
use Slash::Custom::Bulkmail;	# Mail::Bulkmail
use Slash::Utility::Environment;
use Symbol 'gensym';

use base 'Exporter';
use vars qw($VERSION @EXPORT @EXPORT_OK);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(
	bulkEmail
	doEmail
	sendEmail
	doLog
	doLogInit
	doLogPid
	doLogExit
	prog2file
	makeDir
);
@EXPORT_OK = qw();

#========================================================================

=head2 sendEmail(ADDR, SUBJECT, CONTENT [, FROM, PRECEDENCE])

Takes the address, subject and an email, and does what it says.

=over 4

=item Parameters

=over 4

=item ADDR

Mail address to send to.

=item SUBJECT

Subject of mail.

=item CONTENT

Content of mail.

=item FROM

Optional separate "From" address instead of "mailfrom" constant.

=item PRECEDENCE

Optional, set to "bulk" for "bulk" precedence.  Not standard,
but widely supported.

=back

=item Return value

True if successful, false if not.

=item Dependencies

Need From address and SMTP server from vars table,
'mailfrom' and 'smtp_server'.

=back

=cut

# needed?  if so, in vars?
#$Mail::Sendmail::mailcfg{mime} = 0;
sub sendEmail {
	my($addr, $subject, $content, $pr) = @_;
	my $constants = getCurrentStatic();

	unless (Email::Valid->rfc822($addr)) {
		errorLog("Can't send mail '$subject' to $addr: Invalid address");
		return 0;
	}

	my %data = (
		from		=> $constants->{mailfrom},
		smtp		=> $constants->{smtp_server},
		subject		=> $subject,
		body		=> $content,
		to		=> $addr,
		# put in vars ... ?
		'Content-type'	=> 'text/plain; charset="us-ascii"',
		'Content-transfer-encoding'	=> '8bit',
	);

	if ($pr && $pr eq 'bulk') {
		$data{precedence} = 'bulk';
	}

	if (sendmail(%data)) {
		return 1;
	} else {
		errorLog("Can't send mail '$subject' to $addr: $Mail::Sendmail::error");
		return 0;
	}
}

sub bulkEmail {
	my($addrs, $subject, $content) = @_;
	my $constants = getCurrentStatic();

	my $goodfile = catfile($constants->{logdir}, 'bulk-good.log');
	my $badfile  = catfile($constants->{logdir}, 'bulk-bad.log');
	my $errfile  = catfile($constants->{logdir}, 'bulk-error.log');

	# start logging
	for my $file ($goodfile, $badfile, $errfile) {
		my $fh = gensym();
		open $fh, ">> $file\0" or errorLog("Can't open $file: $!"), return;
		printf $fh "Starting bulkmail '%s': %s\n",
			$subject, scalar localtime;
		close $fh;
	}

	my $valid = Email::Valid->new();
	my @list = grep { $valid->rfc822($_) } @$addrs;

	my $bulk = Slash::Custom::Bulkmail->new(
		From    => $constants->{mailfrom},
		Smtp	=> $constants->{smtp_server},
		Subject => $subject,
		Message => $content,
		LIST	=> \@list,
		GOOD	=> $goodfile,
		BAD	=> $badfile,
		ERRFILE	=> $errfile,
	);
	my $return = $bulk->bulkmail;

	# end logging
	for my $file ($goodfile, $badfile, $errfile) {
		my $fh = gensym();
		open $fh, ">> $file\0" or errorLog("Can't open $file: $!"), return;
		printf $fh "Ending bulkmail   '%s': %s\n\n",
			$subject, scalar localtime;
		close $fh;
	}

	return $return;
}

sub doEmail {
	my($uid, $subject, $content, $code, $pr) = @_;

	my $messages = getObject("Slash::Messages");
	if ($messages) {
		$messages->quicksend($uid, $subject, $content, $code, $pr);
	} else {
		my $slashdb = getCurrentDB();
		my $addr = $slashdb->getUser($uid, 'realemail');
		sendEmail($addr, $subject, $content, $pr);
	}
}

sub doLogPid {
	my($fname, $nopid, $sname) = @_;
	$sname ||= $fname;

	my $fh      = gensym();
	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.pid");

	unless ($nopid) {
		if (-e $file) {
			die "$file already exists; you will need " .
			    "to remove it before $fname can start";
		}

		open $fh, "> $file\0" or die "Can't open $file: $!";
		print $fh $$;
		close $fh;
	}

	# do this for all things, not just ones needing a .pid
	$SIG{TERM} = $SIG{INT} = sub {
		doLog($fname, ["Exiting $sname ($_[0]) with pid $$"]);
		# Don't delete the .pid file unless we wrote it.
		# Yes, this next line does what you'd expect;  $nopid is
		# lexically scoped and nested subs inherit the value
		# acquired on the first time the outer sub is called.
		# The Camel book has more info on this phenomenon at its
		# description of the diagnostic message "Variable '%s'
		# will not stay shared" (which won't be a warning here
		# because this inner sub is anonymous).  Oh, and the
		# unlink will silently fail if the file is missing, too.
		unlink $file unless $nopid;
		exit 0;
	};
}

sub doLogInit {
	my($fname, $nopid, $sname) = @_;
	$sname ||= $fname;

	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.log");

	mkpath $dir, 0, 0775;
	doLogPid($fname, $nopid, $sname);
	open(STDERR, ">> $file\0") or die "Can't append STDERR to $file: $!";
	doLog($fname, ["Starting $sname with pid $$"]);
}

sub doLogExit {
	my($fname, $nopid, $sname) = @_;
	$sname ||= $fname;

	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.pid");

	doLog($fname, ["Exiting $sname (exit) with pid $$"]);
	unlink $file unless $nopid;  # fails silently even if $file does not exist
	exit 0;
}

sub doLog {
	my($fname, $msg, $stdout, $sname) = @_;
	chomp(my @msg = @$msg);

	$sname    ||= '';
	$sname     .= ' ' if $sname;
	my $fh      = gensym();
	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.log");
	my $log_msg = scalar(localtime) . " $sname@msg\n";

	open $fh, ">> $file\0" or die "Can't append to $file: $!\nmsg: @msg\n";
	print $fh $log_msg;
	print     $log_msg if $stdout;
	close $fh;
}

# Originally from slashd/runtask
#
# prog2file executes a command (as the unix user specified in your
# /usr/local/slash/slash.sites file, of course, since that's how
# slashd should be running) and puts its output into a file whose
# name is specified.
# 
# Extended: If you are looking for specific data to be returned from the
# program called, prog2file will return a scalar with all data returned from
# STDERR
#
# Of course the params are beginning to get out of hand, but were necessary
# for the move from slashd/runtask.

sub prog2file {
	my($command, $arguments, $f, $verbosity, $handle_err) = @_;
	return 0 unless -e $command and -r _ and -x _;
	$verbosity ||= 0;
	$handle_err ||= 0;
	my $success = 0;
	my $err_str = "";

	my $exec = "$command $arguments";
	my($data, $err);

	# Two ways of handling data from child programs yet we maintain
	# backwards compatibility.
	if (! $handle_err) {
		$data = `$exec`;
	} else {
		# you need to use local() so you don't trample on
		# someone else's IN/OUT/ERR variables anyway, and
		# this takes care of the "used only once" warnings
		# -- pudge
		local(*IN, *OUT, *ERR);
		my $pid = open3(*IN, *OUT, *ERR, $exec);
		my $rc = POSIX::waitpid(-1, WNOHANG);
		{
			undef $/;
			$data = <OUT>;
			$err = <ERR>;
		};
	}
	my $bytes = length $data;

	my $dir = dirname($f);
	my @created = mkpath($dir, 0, 0775) unless -e $dir;
	if (!-e $dir or !-d _ or !-w _) {
		$err_str .= " mkpath($dir) failed '"
			. (-e _) . (-d _) . (-w _)
			. " '@created'";
	} elsif ($bytes == 0) {
		$err_str .= " no data";
	} else {
		my $fh = gensym();
		if (!open $fh, "> $f\0") {
			$err_str .= " could not write to '$f': '$!'";
		} else {
			print $fh $data;
			close $fh;
			$success = 1;
		}
	}

	my($command_base) = $command =~ m{([^/]+)$};
	$command_base ||= $command;
	my $success_str = $success ? "" : " FAILED:$err_str";
	$success_str =~ s/\s+/ /g; chomp $success_str;
	doLog('slashd', [
		join(" ", $command_base, $arguments, "bytes=$bytes$success_str")
	]) if $verbosity >= 2;

	# Old way.
	return $success if ! $handle_err;
	# New way.
	return ($success, $err);
}


# Makes a directory based on a base directory, a section name and a char-based
# SID.
sub makeDir {
	my($bd, $section, $sid) = @_;

	my $yearid  = substr($sid, 0, 2);
	my $monthid = substr($sid, 3, 2);
	my $dayid   = substr($sid, 6, 2);
	my $path    = catdir($bd, $section, $yearid, $monthid, $dayid);

	mkpath $path, 0, 0775;
}



1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$
