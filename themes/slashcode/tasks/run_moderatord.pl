#!/usr/bin/perl -w
#
# $Id$
# 
# Deprecated in favor of the process_moderation.pl task now
# located in plugins/(your moderation plugin here).

use strict;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages);
use Slash::DB;
use Slash::Utility;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '18 0-23 * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{resource_locks} = { };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	return "task deprecated";

};

############################################################

1;

