#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '8 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, this can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $backupdb;
	if ($constants->{backup_db_user}) {
		$backupdb = getObject('Slash::DB',
			$constants->{backup_db_user});
	} else {
		$backupdb = $slashdb;
	}

	slashdLog('Send Subscribe Mail Begin');

	my $subscribers = $slashdb->sqlCount('users_hits', 'hits_paidfor > 0');

	my @numbers = (
		$subscribers
	);

	my $email = sprintf(<<"EOT", @numbers);
$constants->{sitename} Subscriber Info for yesterday

subscribers: %8d
EOT

	if ($constants->{subscribe_secretword} eq 'changemenow') {
		$email .= <<EOT;

*** You have not yet changed your subscribe secret word!    ***
*** Change it now or sneaky users will be able to buy pages ***
*** without actually buying them!  It's the var named:      ***
***                  subscribe_secretword                   ***
*** (See plugins/Subscribe/README for details on using it.) ***

EOT
	}

	$email .= "\n-----------------------\n";

	# Send a message to the site admin.
	for (@{$constants->{stats_reports}}) {
		sendEmail($_,
			"$constants->{sitename} Subscriber Info",
			$email, 'bulk');
	}
	slashdLog('Send Subscribe Mail End');

	return ;
};

1;

