# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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
use Fcntl qw(:flock :seek);
use File::Basename;
use File::Path;
use File::Spec::Functions;
use File::Temp 'tempfile';
use Mail::Sendmail;
use Slash::Constants ();
use Slash::Custom::Bulkmail;	# Mail::Bulkmail
use Slash::Utility::Data;
use Slash::Utility::Environment;
use Symbol 'gensym';
use Time::HiRes ();
use Encode qw(encode);

use open (getCurrentStatic('utf8') ? ':utf8' : ':encoding(us-ascii)');
use open ':std';


use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(
	bulkEmail
	doEmail
	sendEmail
	doLog
	doLogInit
	doLogPid
	doLogExit
	save2file
	prog2file
	makeDir
);
our @EXPORT_OK = qw();

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

	# print errors to slashd.log under slashd only if high level
	# of verbosity -- pudge
	my $log_error = defined &main::verbosity ? main::verbosity() >= 3 : 1;

	unless (emailValid($addr)) {
		errorLog("Can't send mail '$subject' to $addr: Invalid address")
			if $log_error;
		return 0;
	}

	# Character Code Conversion; target encoding must be valid name
	# Characters not representable in the destination character set
	# and encoding will be replaced with \x{HHHH} place-holders
	# (s. Encode(3) perldoc, Handling Malformed Data)
	my $b_code = $constants->{mail_charset_body} || ($constants->{utf8} ? 'UTF-8' : 'us-ascii');
	my $h_code = $constants->{mail_charset_header} || 'MIME-Header';
	if ($constants->{utf8}) {
		$content = encode($b_code, $content, Encode::FB_PERLQQ);
		$subject = encode($h_code, $subject, Encode::FB_PERLQQ);
	}

	my %data = (
		From		=> $constants->{mailfrom},
		Smtp		=> $constants->{smtp_server},
		Subject		=> $subject,
		Message		=> $content,
		To		=> $addr,
		# put in vars ... ?
		'Content-type'			=> qq|text/plain; charset="$b_code"|,
		'Content-transfer-encoding'	=> $constants->{mail_content_transfer_encoding} || '8bit',
		'Message-Id'			=> messageID(),
	);

	if ($pr && $pr eq 'bulk') {
		$data{precedence} = 'bulk';
	}

	my $mail_sent;
	{
		local $^W; # sendmail() should't warn to STDERR
		$mail_sent = sendmail(%data);
	}

	if ($mail_sent) {
		return 1;
	} else {
		errorLog("Can't send mail '$subject' to $addr: $Mail::Sendmail::error")
			if $log_error;
		return 0;
	}
}

{ my($localhost);
sub messageID {
	my $gSkin = getCurrentSkin();

	my $host = $gSkin->{basedomain};
	if (!$localhost) {
		chomp($localhost = `hostname`);
		$localhost ||= '';
	}

	my $msg_id;
	if ($host eq $localhost || !length($localhost)) {
		$msg_id = sprintf('<%f-%d-slash@%s>', Time::HiRes::time(), $$, $host);
	} else {
		$msg_id = sprintf('<%f-%d-slash-%s@%s>', Time::HiRes::time(), $$, $localhost, $host);
	}
	return $msg_id;
}}

sub bulkEmail {
	my($addrs, $subject, $content) = @_;
	my $constants = getCurrentStatic();

	my $goodfile = gensym();
	my $badfile  = gensym();
	my $errfile  = gensym();

	# should we check errors?  probably.  -- pudge
	open $goodfile, ">>" . catfile($constants->{logdir}, 'bulk-good.log');
	open $badfile,  ">>" . catfile($constants->{logdir}, 'bulk-bad.log');
	open $errfile,  ">>" . catfile($constants->{logdir}, 'bulk-error.log');

	# start logging
	for my $fh ($goodfile, $badfile, $errfile) {
		printf $fh "Starting bulkmail '%s': %s\n",
			$subject, scalar localtime;
	}

	my @list = grep { emailValid($_) } @$addrs;

	# Character Code Conversion; see comments in sendEmail()
	my $b_code = $constants->{mail_charset_body} || ($constants->{utf8} ? 'UTF-8' : 'us-ascii');
	my $h_code = $constants->{mail_charset_header} || "MIME-Header";
	if ($constants->{utf8}) {
		$content = encode($b_code, $content, Encode::FB_PERLQQ);
		$subject = encode($h_code, $subject, Encode::FB_PERLQQ);
	}

	my $bulk = Slash::Custom::Bulkmail->new(
		From    => $constants->{mailfrom},
		Smtp	=> $constants->{smtp_server},
		Subject => $subject,
		Message => $content,
		LIST	=> \@list,
		GOOD	=> $goodfile,
		BAD	=> $badfile,
		ERRFILE	=> $errfile,
		# put in vars ... ?
		'Content-type'			=> qq|text/plain; charset="$b_code"|,
		'Content-transfer-encoding'	=> $constants->{mail_content_transfer_encoding} || '8bit',
		'Message-Id'			=> messageID(),
	);
	my $return = $bulk->bulkmail;

	# end logging
	for my $fh ($goodfile, $badfile, $errfile) {
		printf $fh "Ending bulkmail   '%s': %s\n\n",
			$subject, scalar localtime;
		# will close when $bulk goes anyway anyway
		#close $fh;
	}

	return $return;
}

# doEmail may be used to send mail to any arbitrary email address,
# as $tuser is normally a UID, but may be an email address
sub doEmail {
	my($tuser, $subject, $content, $code, $pr) = @_;

	my $messages = getObject("Slash::Messages");
	if ($messages) {
		$messages->quicksend($tuser, $subject, $content, $code, $pr);
	} else {
		if ($tuser !~ /\D/) {
			my $slashdb = getCurrentDB();
			$tuser = $slashdb->getUser($tuser, 'realemail');
		}
		sendEmail($tuser, $subject, $content, $pr);
	}
}

{
my $exit_func;
sub doLogPid {
	my($fname, $options) = @_;
	my $nopid = $options->{nopid};
	my $sname = $options->{sname} || $fname;
	$exit_func = $options->{exit_func};

	my $fh      = gensym();
	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.pid");

	# Right now we use a fairly dumb method of deciding whether a copy
	# of this program is already running.  If there's a pidfile, we
	# don't start.  If we wanted to get more sophisticated, here would
	# be a good place:  we should check the pid value inside the file
	# and use Proc::ProcessTable to see whether there is a copy of this
	# program already running with that pid.  Or maybe we should check
	# whether there is *any* copy of this program running already.
	# If zero, ignore the pidfile and start up;  if one, write an
	# error and die;  if more than one, write a really nasty error...?
	# XXX - Jamie 2002/03/19
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
		&$exit_func() if $exit_func;
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
}

sub doLogInit {
	my($fname, $options) = @_;
	$options ||= { };
	my $nopid = $options->{nopid};
	my $sname = $options->{sname} || $fname;
	my $exit_func = $options->{exit_func};

	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.log");

	mkpath $dir, 0, 0775;
	doLogPid($fname, {
		nopid => $nopid,
		sname => $sname,
		exit_func => $exit_func
	});
	open(STDERR, ">> $file\0") or die "Can't append STDERR to $file: $!";
	doLog($fname, ["Starting $sname with pid $$"]);
}

sub doLogExit {
	my($fname, $options) = @_;
	$options ||= { };
	my $nopid = $options->{nopid};
	my $sname = $options->{sname} || $fname;

	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.pid");

	doLog($fname, ["Exiting $sname (exit) with pid $$"]);
	unlink $file unless $nopid;  # fails silently even if $file does not exist
	exit 0;
}

sub doLog {
	my($fname, $msg, $stdout, $sname) = @_;
	my $constants = getCurrentStatic();
	my @msg;
	if (ref($msg) && ref($msg) eq 'ARRAY') {
		@msg = @$msg;
	} else {
		@msg = ( $msg );
	}
	chomp(@msg);

	$sname    ||= '';
	$sname     .= ' ' if $sname;
	my $fh      = gensym();
	my $dir     = $constants->{logdir};
	my $file    = catfile($dir, "$fname.log");
	my $log_msg = scalar(localtime) . " $sname@msg\n";

	open $fh, ">> $file\0" or die "Can't append to $file: $!\nmsg: @msg\n";
	flock($fh, LOCK_EX) if $constants->{logdir_flock};
	seek($fh, 0, SEEK_END);
	print $fh $log_msg;
	print     $log_msg if $stdout;
	close $fh;
}

# Originally from open_backend.pl
# will write out any data to a given file, but first check to see
# if the data has changed, so clients don't
# re-FETCH the file; if they send an If-Modified-Since, Apache
# will just return a header saying the file has not been modified

# $fudge is an optional coderef to munge the data before comparison

sub save2file {
	my($file, $data, $fudge) = @_;

	if (open my $fh, '<', $file) {
		my $current = do { local $/; <$fh> };
		close $fh;
		my $new = $data;
		($current, $new) = $fudge->($current, $new) if $fudge;
		return if $current eq $new;
	}

	if (open my $fh, '>', $file) {
		print $fh $data;
		close $fh;
		return 1;
	} else {
		warn "Can't open > $file: $!";
		return 0;
	}
}



# Originally from slashd/runtask
#
# prog2file executes a command (as the unix user specified in your
# /usr/local/slash/slash.sites file, of course, since that's how
# slashd should be running) and puts its output into a file whose
# name is specified.
# 
# Extended: If you are looking for specific data to be returned from the
# program called, prog2file will return a scalar with all data returned
# from STDERR
#
# The API was changed on 2002/06/01 to have the options be modular.
# - Jamie

sub prog2file {
	my($command, $filename, $options) = @_;
	# was: ($comment, $arguments, $f, $verbosity, $handle_err) = @_;
	return 0 unless -e $command and -r _ and -x _;
	my $arguments = $options->{args} || "";
	$arguments = join(" ", @$arguments)
		if ref($arguments) && ref($arguments) eq 'ARRAY';
	$arguments = " $arguments" if $arguments;
	my $verbosity = $options->{verbosity} || 0;
	my $handle_err = $options->{handle_err} || 0;

	my $exec = "$command$arguments";
	my $success = 0;
	my $err_str = "";
	my $data = undef;
	my $stderr_text = "";

	# Two ways of handling data from child programs yet we maintain
	# backwards compatibility.
	# Passing "timeout" as a field to $options does what you'd think.
	# A timeout of 0 means "never time out".  30 seconds is default.
	my $timeout = 30;
	$timeout = $options->{timeout} if defined($options->{timeout});
	my($errfh, $errfile) = (undef, undef);
	eval {
		local $SIG{ALRM} = sub { die "timeout" };
		alarm $timeout if $timeout;
		if (!$handle_err) {
			$data = `$exec`;
			alarm 0 if $timeout;
		} else {
			($errfh, $errfile) = tempfile();
			$data = `$exec 2>$errfile`;
			alarm 0 if $timeout;
			$stderr_text = join '', <$errfh>;
			close $errfh; $errfh = undef;
			unlink $errfile; $errfile = undef;
		}
	};
	my $success_str = "";
	if ($timeout && $@ && $@ =~ /timeout/) {
		$success_str = " TIMEOUT_HIT";
		close $errfh if $errfh;
		unlink $errfile if $errfile;
	}
	my $bytes = defined($data) ? length($data) : 0;

	if ($stderr_text =~ /\b(ID \d+, \w+;\w+;\w+) :/) {
		my $template = $1;
		my $error = "task operation aborted, error in template $template";
		$err_str .= " $error";
		# template error, don't write file
		if (defined &main::slashdErrnote) {
			main::slashdErrnote("$error: $stderr_text");
		} else {
			doLog('slashd', ["$error: $stderr_text"]);
		}
	} else {
		my $dir = dirname($filename);
		my @created = mkpath($dir, 0, 0775) unless -e $dir;
		if (!-e $dir or !-d _ or !-w _) {
			$err_str .= " mkpath($dir) failed '"
				. (-e _) . (-d _) . (-w _)
				. " '@created'";
		} elsif ($bytes == 0) {
			$err_str .= " no data";
		} else {
			my $fh = gensym();
			if (!open $fh, "> $filename\0") {
				$err_str .= " could not write to '$filename': '$!'";
			} else {
				binmode $fh, ":encoding($options->{encoding})" if (defined($options->{encoding}));
				print $fh $data;
				close $fh;
				$success = 1;
			}
		}
	}

	my($command_base) = $command =~ m{([^/]+)$};
	$command_base ||= $command;
	$success_str .= $success ? "" : " FAILED:$err_str";
	$success_str =~ s/\s+/ /g; chomp $success_str;

	if ($verbosity >= 2) {
		my $logdata = "$command_base$arguments bytes=$bytes$success_str";
		if (defined &main::slashdLog) {
			main::slashdLog($logdata);
		} else {
			doLog('slashd', [$logdata]);
		}
	}

	# Old way.
	return $success if ! $handle_err;
	# New way.
	return($success, $stderr_text);
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
