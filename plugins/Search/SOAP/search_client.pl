#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use SOAP::Lite;

my $host        = 'slash.tangent.org';
my $uri         = "http://$host/Slash/Search/SOAP";
my $proxy       = "http://$host/soap.pl";

# add example later for showing authentication with cookies, both
# with cookie files, and with creating your own cookie

my $soap = SOAP::Lite->uri($uri)->proxy($proxy);

my $stories = $soap->findStory("This is new")->result;

for (@$stories) {
	print "$_->{title}\n";
}

__END__
