#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use SOAP::Lite;

my $host        = 'yaz.pudge.net:8080';
my $uri         = "http://$host/Slash/SOAP/Test";
my $proxy       = "http://$host/soap.pl";

# add example later for showing authentication with cookies, both
# with cookie files, and with creating your own cookie

my $soap = SOAP::Lite->uri($uri)->proxy($proxy);

my $uid = 2;
my $nick = $soap->get_nickname($uid)->result;
my $nuid = $soap->get_uid($nick)->result;

print "Results for UID $uid: $nickname ($nuid)\n";

__END__
