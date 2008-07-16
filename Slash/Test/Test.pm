# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Test;

=head1 NAME

Slash::Test - Command-line Slash testing


=head1 SYNOPSIS

	% perl -MSlash::Test -e 'print Dumper $user'


	# virtualuser is assumed to be "slash" if not specified
	% perl -MSlash::Test=virtualuser -e 'print Dumper $user'


	# use freely in test scripts
	#!/usr/bin/perl -w
	use Slash::Test qw(virtualuser);
	print Dumper $user;


	# Display, Test by template name
	% perl -MSlash::Test -we 'Display("motd;misc;default")'
	% perl -MSlash::Test -we 'Test("motd;misc;default")'


	# Display, Test by filename
	% cat motd\;misc\;default | perl -MSlash::Test -weDisplay
	% cat motd\;misc\;default | perl -MSlash::Test -weTest


	# Display, Test by template text
	% perl -MSlash::Test -we Display
	Current user is [% user.nickname %] ([% user.uid %])
	^DCurrent user is Anonymous Coward (1)

	% perl -MSlash::Test -we Test
	Current user is [% user.nickname %] ([% user.uid ; END %])
	^DError in library:Slash::Test:.../Test.pm:216:anon : file error -
	parse error: anon_1 line 1: unexpected token (END)
	  [% user.uid ; END %]

	Which was called by:main:-e:1:anon : file error - parse error:
	anon_1 line 1: unexpected token (END)
	  [% user.uid ; END %]


=head1 DESCRIPTION

Will export everything from Slash, Slash::Utility, Slash::Display,
Slash::Constants, Slash::XML, and Data::Dumper into the current namespace.
Will export $user, $anon, $form, $constants, $slashdb, and $gSkin as global
variables into the current namespace, along with a few other useful
variables: $self (alias to $slashdb), $reader_db, $log_db, $writer_db,
and $search_db.

Also the name of each plugin will be a global variable referencing its
object (e.g., C<$journal> is automatically created as a L<Slash::Journal>
object).

So use it one of three ways (use the default Virtual User,
or pass it in via the import list, or pass in with slashTest()), and then
just use the Slash API in your one-liners.

It is recommended that you change the hardcoded default to whatever
Virtual User you use most.

You can also pass in a UID to use instead of anonymous coward:

	% perl -MSlash::Test=virtualuser,2 -e 'print Dumper $user'

Plugin variables automatically spring into existence, such as $journal, $messages,
etc.  Feel free to do:

	% perl -MSlash::Test -e 'print Dumper $journal->themes'

=head1 EXPORTED FUNCTIONS

=cut

BEGIN { $ENV{TZ} = 'GMT' }

use Data::Dumper;
use File::Spec::Functions;
use Storable qw(nfreeze thaw);

use Slash;
use Slash::Constants ':all';
use Slash::Display;
use Slash::Utility;
use Slash::XML;

use strict;
use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT = (
	@Slash::EXPORT,
	@Slash::Constants::EXPORT_OK,
	@Slash::Display::EXPORT,
	@Slash::Utility::EXPORT,
	@Slash::XML::EXPORT,
	@Data::Dumper::EXPORT,
	qw(nfreeze thaw),
	'slashTest',
	'Display',
	'Test',
);

# "manually" export @EXPORT symbols
Slash::Test->export_to_level(1, '', @EXPORT);

# allow catching of virtual user in import list
sub import {
	slashTest($_[1] || 'slash');
	createCurrentUser($::user = prepareUser($_[2], $::form, $0)) if $_[2];
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
$form, $constants, $slashdb, and $gSkin into current namespace.  $self
is an alias to $slashdb.

=back

=cut


sub slashTest {
	my($VirtualUser, $noerr) = @_;

	die 'No virtual user' unless defined $VirtualUser and $VirtualUser ne '';
	unshift @ARGV, 'virtual_user=' . $VirtualUser;
	eval { createEnvironment() };
	die $@ if $@ && !$noerr;

	setCurrentSkin(determineCurrentSkin());

	$::self = $::slashdb = getCurrentDB();
	$::constants = getCurrentStatic();
	$::user      = getCurrentUser();
	$::anon      = getCurrentAnonymousCoward();
	$::form      = getCurrentForm();
	$::gSkin     = getCurrentSkin();

	$::reader_db	= getObject('Slash::DB', { db_type => 'reader' });
	$::writer_db	= getObject('Slash::DB', { db_type => 'writer' });
	$::log_db	= getObject('Slash::DB', { db_type => 'log'    });
	$::search_db	= getObject('Slash::DB', { db_type => 'search' });

	# auto-create plugin variables ... bwahahaha
	my $plugins = $::slashdb->getDescriptions('plugins');
	local $Slash::Utility::NO_ERROR_LOG = 1;

	for my $plugin (grep { /^\w+$/ } keys %$plugins) {
		my $name = lc $plugin;
		my $object = getObject("Slash::$plugin");
		if ($object) {
			no strict 'refs';
			no warnings 'once';
			${"main::$name"} = $object;
		}
	}

	$Data::Dumper::Sortkeys = 1;
}

#========================================================================

=head2 Display(TEMPLATE [, HASHREF, RETURN])

A wrapper for slashDisplay().

Pass in the full name of a template (e.g., "motd;misc;default", or just
"motd" to accept default for page and skin), and an optional HASHREF
of data.

Nocomm is true.  Default is to print (else make RETURN true).

If first arg is false, then takes template from STDIN: you can type in
your template on the command line, then, and hit ctrl-D or whatever
to end.

=cut

sub Display {
	my($template, $hashref, $return) = @_;

	($template, my($data)) = _getTemplate($template);
	$data = { %$data, Nocomm => 1, Return => $return };

	slashDisplay($template, $hashref, $data);
}

#========================================================================

=head2 Test(TEMPLATE [, HASHREF])

Tests a template.

Pass in the full name of a template (e.g., "motd;misc;default", or just
"motd" to accept default for page and skin), and an optional HASHREF
of data.

No output is produced, only errors.

If first arg is false, then takes template from STDIN: you can type in
your template on the command line, then, and hit ctrl-D or whatever
to end.

=cut

sub Test {
	my($template, $hashref) = @_;

	($template, my($data)) = _getTemplate($template);
	$data = { %$data, Nocomm => 1, Return => 1 };

	slashDisplay($template, $hashref, $data);
}

#========================================================================
# used by Display, Test
sub _getTemplate {
	my($template) = @_;

	my($page, $skin, $data) = ('', '', {});
	if (!$template) {
		$template = '';
		while (<>) {
			$template .= $_;
		}
		$template = \ "$template";  # anon template should be a reference
	} elsif ($template =~ /^(\w+);(\w+);(\w+)$/) {
		($template, $page, $skin) = ($1, $2, $3)
	}

	$data->{Page} = $page if $page;
	$data->{Skin} = $skin if $skin;

	return($template, $data);
}


1;

__END__


=head1 SEE ALSO

Slash(3).
