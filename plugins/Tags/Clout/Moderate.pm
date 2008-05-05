package Slash::Clout::Moderate;

use strict;
use warnings;
use Slash::Utility;
use base 'Slash::Clout';

our $VERSION = $Slash::Constants::VERSION;

sub init {
	1;
}

sub getUserClout {
	my($class, $user_stub) = @_;
	return 1;
}

sub get_nextgen {
	return [ ];
}

sub process_nextgen {
	return [ ];
}

sub insert_nextgen {
}

sub update_tags_peerclout {
}

sub copy_peerclout_sql {
}

1;

