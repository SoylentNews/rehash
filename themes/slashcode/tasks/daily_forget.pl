#!/usr/bin/perl -w

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '2 7 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;
	my $forgotten1 = $slashdb->forgetCommentIPs();
	my $forgotten2 = $slashdb->forgetSubmissionIPs();
	return "forgot approx $forgotten1 comments, $forgotten2 submissions";
};

1;

