# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::SOAP;

use strict;
use Slash;
use Slash::Utility;

use vars qw( $VERSION $ERROR );
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Slash::SOAP - SOAP access for Slash


=head1 SYNOPSIS

	# helper methods for SOAP


=head1 DESCRIPTION

This plugin provides helper methods for using SOAP with other plugins.

=cut

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'SOAP'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub returnError {
	my($self, $error) = @_;
	return $error || $ERROR || 'Unknown error';
}

{
my %loaded;

# all these error messages will be put into templates later, don't worry ...
sub handleMethod {
	my($self, $action) = @_;
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();

	unless ($constants->{soap_enabled}) {
		$ERROR = 'SOAP not enabled';
		return;
	}

	# security problem previous to 0.55
	unless (SOAP::Lite->VERSION >= 0.55) {
		$ERROR = sprintf('SOAP::Lite version %d insecure, please update to 0.55 or greater', SOAP::Lite->VERSION);
		return;
	}

	# pull out class and method from the action
	$action =~ m|^("?)https?://[^/]+?/([\w/]+)#(\w+)\1$|;
	my($class, $method) = ($2, $3);
	$class =~ s|/|::|g;
	my $newaction = $class . '::' . $method;

	my $data = $self->getClassMethod($class, $method);

	unless ($data) {
		$ERROR = sprintf('Method %s::%s not found', $class, $method);
		return;
	}

	unless ($user->{seclev} >= $data->{seclev}) {
		$ERROR = 'Current user does not have access to this method';
		return;
	}

	if ($data->{subscriber_only} && !$user->{is_subscriber}) {
		$ERROR = 'Current user does not have access to this method';
		return;
	}

	return unless $self->validFormkey($class, $method, $data->{formkeys});

	# attempt to load module ourselves
	# exists $loaded{"$file.pm"} true if we TRIED to load,
	# so we don't keep retrying on failure
	(my $file = $class) =~ s|::|/|g;
	if (!exists $loaded{"$file.pm"} && !exists $INC{"$file.pm"}) {
		eval "require $class";
		$loaded{"$file.pm"} = 1;
	}

	# all good!
	return $newaction;
}
}

# needs caching
sub getClassMethod {
	my($self, $class, $method) = @_;

	my $data = $self->sqlSelectHashref(
		'id, class, method, seclev, subscriber_only, formkeys',
		'soap_methods',
		join(' AND ',
			'class = '  . $self->sqlQuote($class),
			'method = ' . $self->sqlQuote($method)
		)
	);
	return $data;
}


sub validFormkey {
	my($self, $class, $method, $checks) = @_;

	return 1 unless $checks;

	my($slashdb) = getCurrentDB();

	$class =~ /\b(\w+)(::SOAP)?$/;
	my $formname = lc $1;  # 'search', 'journal', etc.
	$formname .= '/' . $method;

	# create formkey in DB, and stick it in $form, where
	# formkeyHandler will find it
	$slashdb->createFormkey($formname);

	my $error;
	my @checks = split /\s*,\s*/, $checks;
	push @checks, 'formkey_check';  # always perform this check
	for (@checks) {
		# stop checking when we hit an error
		last if formkeyHandler($_, $formname, 0, \$error);
	}

	if ($error) {
		# these error messages should be run through strip_html, or something
		# play around with it
		$ERROR = $error;
		return 0;
	} else {
		# why does anyone care the length?
		$slashdb->updateFormkey(0, 1);
		return 1;
	}
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
