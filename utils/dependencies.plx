#!/usr/bin/perl -w
# this attempts to make sure there are no dependency conflicts.
# run it every once in awhile if you care to.
#
# $Id$
#

sub warner { warn @_ unless $_[0] =~ /(?:Use of uninitialized value|[Ss]ubroutine \S+ redefined)/ }
$SIG{__WARN__} = \&warner;

my %data;

package Slash::Test::Dependencies;
use strict;

use base 'Exporter';
our @EXPORT = ('require');

sub require {
	my $caller = caller(0);
	$caller = caller(2) if $caller eq 'base';

	my $package = my $required = shift;

	return if $package =~ /^\d/;

	$package =~ s/\.pm$//;
	$package =~ s|/|::|g;

#	printf "%s called %s (%s)\n", $caller, $required, $package;
	push @{$data{$caller}}, $package;
	CORE::require $required;
}


# for when we "use base" to get a module
*base::import_new = *base::import{CODE};
*base::import = sub {
	my $caller = caller(0);
	my $package = $_[1];

#	printf "%s called %s (%s)\n", $caller, $required, $package;
	push @{$data{$caller}}, $package;
	goto &base::import_new;
};
Slash::Test::Dependencies->export('base', 'require');


package main;
use strict;

use File::Find;
die $0;
my $path = shift @ARGV || '/usr/local/src/slash/main/slash/';
$path .= '/' unless $path =~ m|/$|;

my %pms;
my $skip = qr{(?:Bundle::Slash|Slash::SOAP::WSDL|Slash::Apache(?:::(?:User|Banlist))?)$};
find(sub {
	my $file = $File::Find::name;
	if ($file =~ /\.pm$/) {
		(my $f = $file) =~ s|^\Q$path\E||;
		$f =~ s/\.pm$//;
		$f =~ s/^plugins/Slash/;
		$f =~ s|\b(\w+)/\1$|$1|;
		$f =~ s|/|::|g;
		return if $f =~ $skip;
		$pms{$f} ||= $file;
	} else {
		return;
	}
}, $path);

for my $f (sort keys %pms) {
#	next unless $f eq 'Slash::DB::MySQL';
	$SIG{__WARN__} = \&warner;
	Slash::Test::Dependencies->export($f, 'require');
	require $pms{$f};
}

# make sure we get an error, for testing
#push @{$data{'Slash::Utility'}}, 'Slash::DB::MySQL';
#push @{$data{'Slash::DB::MySQL'}}, 'Slash::Utility';
use Data::Dumper;
print Dumper \%data;

for my $class (keys %data) {
	my $aref = $data{$class};
	$data{$class} = { map { ($_ => 1) } @$aref };
}

my %checked;
for my $class (keys %data) {
	for my $sub (keys %{$data{$class}}) {
		check($class, $sub, [$class, $sub]);
	}
}

print "All OK!\n";

sub check {
	my($class, $sub, $trace) = @_;

	return if $checked{$class,$sub};
	$checked{$class,$sub}++;

	for (keys %{$data{$sub}}) {
		my $ntrace = [@$trace, $_, $class];
		local $" = " =>\n\t";
		if (exists $data{$_}{$class}) {
			die "damn:\n\t@$ntrace\n";
		}
		check($class, $_, [@$trace, $_]);
	}
}


__END__

my %data = (
	'Slash' => [qw(
		Slash::Constants
		Slash::DB
		Slash::Display
		Slash::Utility
	)],
	'Slash::Apache' => [qw(
		Slash
		Slash::DB
		Slash::Display
		Slash::Utility
	)],
	'Slash::Apache::Log' => [qw(
		Slash::Utility
	)],
	'Slash::Apache::User' => [qw(
		Slash
		Slash::Apache
		Slash::Display
		Slash::Utility
	)],
	'Slash::Constants' => [qw(
	)],
	'Slash::DB' => [qw(
		Slash::DB::Utility
	)],
	'Slash::DB::MySQL' => [qw(
		Slash::DB
		Slash::DB::Utility
		Slash::Utility
	)],
	'Slash::DB::Static::MySQL' => [qw(
		Slash::DB::Utility
		Slash::Utility
	)],
	'Slash::DB::Utility' => [qw(
		Slash::Utility
	)],
	'Slash::Display' => [qw(
		Slash::Display::Provider
		Slash::Utility::Data
		Slash::Utility::Environment
		Slash::Utility::System
	)],
	'Slash::Display::Plugin' => [qw(
		Slash
		Slash::Utility
	)],
	'Slash::Display::Provider' => [qw(
		Slash::Utility::Environment
	)],
	'Slash::Install' => [qw(
		Slash
		Slash::DB
		Slash::DB::Utility
	)],
	'Slash::Test' => [qw(
		Slash
		Slash::Constants
		Slash::Display
		Slash::Utility
		Slash::XML
	)],
	'Slash::Utility' => [qw(
		Slash::Utility::Access
		Slash::Utility::Anchor
		Slash::Utility::Data
		Slash::Utility::Display
		Slash::Utility::Environment
		Slash::Utility::System
	)],
	'Slash::Utility::Access' => [qw(
		Slash::Display
		Slash::Utility::Data
		Slash::Utility::System
		Slash::Utility::Environment
	)],
	'Slash::Utility::Anchor' => [qw(
		Slash::Display
		Slash::Utility::Data
		Slash::Utility::Display
		Slash::Utility::Environment
	)],
	'Slash::Utility::Data' => [qw(
		Slash::Constants
		Slash::Utility::Environment
	)],
	'Slash::Utility::Display' => [qw(
		Slash::Display
		Slash::Utility::Data
		Slash::Utility::Environment
	)],
	'Slash::Utility::Environment' => [qw(
	)],
	'Slash::Utility::System' => [qw(
		Slash::Utility::Environment
	)],
);
