package Slash::API;

use base 'Slash::Plugin';
our $VERSION = $Slash::Constants::VERSION;

use strict;
use JSON;
use Data::Dumper;
use Encode 'encode_utf8';
use Slash::Utility::Data;
use Slash::Utility::Display;
use Slash::Utility::Environment;
use Apache;
use Apache::Constants ':http';

my $jsonFlags = { utf8 => 1, pretty => 1 };
binmode(STDOUT, ':encoding(utf8)');

# constructor method. Initializes and returns Slash::Subscribe::IPN object
sub new {
	my ($class, $data) = @_;
	$class = ref($class) || $class;

	my $self = { 
		version => '0.01',
	};

	bless $self, $class;

	return $self;
}

sub header {
	my $r = Apache->request;
	$r->header_out('Cache-Control', 'no-cache');
	$r->header_out('Pragma', 'no-cache');
	$r->header_out('Content-Type', "application/json; charset=UTF-8");
	$r->send_http_header;
}

1;
