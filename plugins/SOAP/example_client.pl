#!/usr/bin/perl -wl
use strict;
use Data::Dumper;
use SOAP::Lite;

my $host        = 'www.example.com';
my $uri         = "http://$host/Slash/SOAP/Test";
my $proxy       = "http://$host/soap.pl";

# add example later for showing authentication with cookies, both
# with cookie files, and with creating your own cookie

my $soap = SOAP::Lite->uri($uri)->proxy($proxy);
print Dumper $soap->get_user(2)->result;
print "Done.\n";

__END__
