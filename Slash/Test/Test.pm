# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Test;

=head1 NAME

Slash::Test - Command-line Slash testing


=head1 SYNOPSIS

	% perl -MSlash::Test -wle Display
	Current user is [% user.nickname %] ([% user.uid %])
	^DCurrent user is Anonymous Coward (1)

	% perl -MSlash::Test -e 'print Dumper $user'

	% perl -MSlash::Test=virtualuser -e 'print Dumper $user'

	#!/usr/bin/perl -w
	use Slash::Test qw(virtualuser);
	print Dumper $user;

=head1 DESCRIPTION

Will export everything from Slash, Slash::Utility, Slash::Display,
Slash::Constants, Slash::XML, and Data::Dumper into the current namespace.
Will export $user, $anon, $form, $constants, and $slashdb as global variables
into the current namespace.

So use it one of three ways (use the default Virtual User,
or pass it in via the import list, or pass in with slashTest()), and then
just use the Slash API in your one-liners.

It is recommended that you change the hardcoded default to whatever
Virtual User you use most.

You can also pass in a UID to use instead of anonymous coward:

	% perl -MSlash::Test=virtualuser,2 -e 'print Dumper $user'

=head1 EXPORTED FUNCTIONS

=cut

BEGIN { $ENV{TZ} = 'GMT' }
use Slash;
use Slash::Constants ':all';
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use Data::Dumper;

use strict;
use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT = (
	@Slash::EXPORT,
	@Slash::Constants::EXPORT_OK,
	@Slash::Display::EXPORT,
	@Slash::Utility::EXPORT,
	@Slash::XML::EXPORT,
	@Data::Dumper::EXPORT,
	'slashTest',
	'Display',
);

# "manually" export @EXPORT symbols
Slash::Test->export_to_level(1, '', @EXPORT);

# allow catching of virtual user in import list
sub import {
    slashTest($_[1] || 'slash');
    createCurrentUser($::user = $::slashdb->getUser($_[2])) if $_[2];
}

#========================================================================

=head2 slashTest([VIRTUALUSER])

Set up the environment, with a new Virtual User.

Called automatically when module is first used.  Should only be called
if changing the Virtual User from the default (by default, "slash").
Called without an argument, uses the default.

=over 4

=item Parameters

=over 4

=item VIRTUALUSER

Your site's virtual user.

=back

=item Return value

None.

=item Side effects

Set up the environment with createEnvironment(), export $user, $anon,
$form, $constants, and $slashdb into current namespace.

=back

=cut


sub slashTest {
	my($VirtualUser, $noerr) = @_;

	die 'No virtual user' unless defined $VirtualUser and $VirtualUser ne '';
	push @ARGV, 'virtual_user=' . $VirtualUser;
	eval { createEnvironment() };
	die $@ if $@ && !$noerr;

	$::slashdb   = getCurrentDB();
	$::constants = getCurrentStatic();
	$::user      = getCurrentUser();
	$::anon      = getCurrentAnonymousCoward();
	$::form      = getCurrentForm();

	# auto-create plugin variables ... bwahahaha
	my $plugins = $::slashdb->getDescriptions('plugins');
	local $Slash::Utility::NO_ERROR_LOG = 1;

	for my $plugin (grep { /^\w+$/ } keys %$plugins) {
		my $name = lc $plugin;
		my $object = getObject("Slash::$plugin");
		if ($object) {
			no strict 'refs';
			${"main::$name"} = $object;
		}
	}
}

#========================================================================

=head2 Display(TEMPLATE [, HASHREF, RETURN])

A wrapper for slashDisplay().  Pass in a template string (not a template
name) and optional hashref of variables.  Nocomm is true.  Default is to
print (else make third param true).

If first arg is false, then takes template from STDIN.  You can type in
your template on the command line, then, and hit ctrl-D or whatever
to end.

=cut

sub Display {
	my($template, $hashref, $return) = @_;
	if (!$template) {
		$template = '';
		while (<>) {
			$template .= $_;
		}
	}
	slashDisplay(\$template, $hashref, { Nocomm => 1, Return => $return });
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
