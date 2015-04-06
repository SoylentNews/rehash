package Slash::Gopher;

use strict;
use vars qw(@ISA);
use Net::Server::PreFork; # any personality will do

@ISA = qw(Net::Server::PreFork);

sub process_request {
    my $self = shift;
    while (<STDIN>) {
        print "iGopher Test	test	error.host	1";
	print "\n";
        last;
    }
}

