# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Display;

=head1 NAME

Slash::Display - Display library for Slash


=head1 SYNOPSIS

	slashDisplay('some template', { key => $val });
	my $text = slashDisplay('template', \%data, 1);


=head1 DESCRIPTION

Slash::Display uses Slash::Display::Provider to provide the
template data from the Slash::DB API.

It will process and display a template using the data passed in.
In addition to whatever data is passed in the hashref, the contents
of the user, form, and static objects, as well as the %ENV hash,
are available.

C<slashDisplay> will print by default to STDOUT, but will
instead return the data if the third parameter is true.  If the fourth
parameter is true, HTML comments surrounding the template will NOT
be printed or returned.  That is, if the fourth parameter is false,
HTML comments noting the beginning and end of the template will be
printed or returned along with the template.

L<Template> for more information about templates.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use base 'Exporter';
use vars qw($VERSION @EXPORT @EXPORT_OK $CONTEXT);
use Exporter ();
use Slash::Display::Provider ();
use Slash::Utility;
use Template;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(slashDisplay);
@EXPORT_OK = qw(get_template);

# BENDER: Well I don't have anything else planned for today, let's get drunk!

#========================================================================

=head2 slashDisplay(NAME [, DATA, OPTIONS])

Processes a template.

=over 4

=item Parameters

=over 4

=item NAME

Can be either the name of a template block in the Slash DB,
or a reference to a scalar containing a template to be
processed.  In both cases, the template will be compiled
and the processed, unless it has previously been compiled,
in which case the cached, compiled template will be pulled
out and processed.

=item DATA

Hashref of additional parameters to pass to the template.
Default passed parameters include constants, env, user, and
form, which can be overriden (see C<_populate>).

=item OPTIONS

Hashref of options.  Currently supported options are below.
If OPTIONS is the value C<1> instead of a hashref, that will
be the same as if the hashref were C<{ Return =E<gt> 1 }>.

=over 4

=item Return

Boolean for whether to print (false) or return (true) the
processed template data.  Default is print.

=item Nocomm

Boolean for whether to include (false) or not include (true)
HTML comments surrounding template, stating what template
block this is.  Default is to include comments.

=item Section (REWRTIE)

All templates named NAME may be overriden by a template named
"SECTION_NAME" (e.g., the "header" template, may be overridden
in the "tacohell" section with a template named "tacohell_header").

By default, that section will be determined by whatever the current
section is (or "light" if the user is in light mode).  However,
the default can be overriden by the Section option.  Also, a Section
value of "NONE" will cause no section to be used.

=item Page (REWRTIE)

All templates named NAME may be overriden by a template named
"SECTION_NAME" (e.g., the "header" template, may be overridden
in the "tacohell" section with a template named "tacohell_header").

By default, that section will be determined by whatever the current
section is (or "light" if the user is in light mode).  However,
the default can be overriden by the Section option.  Also, a Section
value of "NONE" will cause no section to be used.

=back

=back

=item Return value

If OPTIONS-E<gt>{Return} is true, the processed template data.
Otherwise, returns true/false for success/failure.

=item Side effects

Compiles templates and caches them.

=back

=cut

sub slashDisplay {
	my($name, $data, $opt) = @_;
	my(@comments, $err, $ok, $out, $origSection, $origPage,
		$tempdata, $tempname, $user, $slashdb);
	return unless $name;

	$slashdb = getCurrentDB();
	$user = getCurrentUser();

	# save for later (local() seems not to work ... ?)
	$origSection = $user->{currentSection};
	$origPage = $user->{currentPage};	

	# allow slashDisplay(NAME, DATA, RETURN) syntax
	if (! ref $opt) {
		$opt = $opt == 1 ? { Return => 1 } : {};
	}

	if ($opt->{Section} eq 'NONE') {
		$user->{currentSection} = 'default';
	# admin and light are special cases
	} elsif ($user->{currentSection} eq 'admin') {
		$user->{currentSection} = 'admin';
	} elsif ($user->{light}) {
		$user->{currentSection} = 'light';
	} elsif ($opt->{Section}) {	
		$user->{currentSection} = $opt->{Section};
	}

	if ($opt->{Page} eq 'NONE') {
		$user->{currentPage} = 'misc';
	} elsif ($opt->{Page}) {	
		$user->{currentPage} = $opt->{Page};
	}

	for (qw[currentSection currentPage]) {
		$user->{$_} = defined $user->{$_} ? $user->{$_} : '';
	}


	if (ref $name) {
		@comments = (
			"\n\n<!-- start template: anon -->\n\n",
			"\n\n<!-- end template: anon -->\n\n"
		);
	} else {
		# we don't want to have to call this here, but because
		# it is cached the performance his it is generally light,
		# and this is the only good way to get the actual name,
		# page, section, we bite the bullet and do it
		$tempdata = $slashdb->getTemplateByName($name, [qw(tpid page section)]);

		# we could, at this point, just return from the
		# function if $tempdata->{tpid} is undef ...
		# do we want to try?  for now leave it in.

		$tempname = "ID $tempdata->{tpid}, " .
			"$name;$tempdata->{page};$tempdata->{section}";
		@comments = (
			"\n\n<!-- start template: $tempname -->\n\n",
			"\n\n<!-- end template: $tempname -->\n\n"
		);
	}

	$data ||= {};
	_populate($data);

	# let us pass in a context if we have one
	my $template = $CONTEXT || get_template();

	if ($CONTEXT) {
		$ok = eval { $out = $template->include($name, $data) };
		$err = $@ if !$ok;
	} else {
		$ok = $template->process($name, $data, \$out);
		$err = $template->error if !$ok;
	}

	$out = $comments[0] . $out . $comments[1] unless $opt->{Nocomm};

	if ($ok) {
		print $out unless $opt->{Return};
	} else {
		errorLog("$tempname : $err");
	}

	# restore our original values
	$user->{currentSection}	= $origSection;
	$user->{currentPage}	= $origPage;

	return $opt->{Return} ? $out : $ok;
}

#========================================================================

=head1 NON-EXPORTED FUNCTIONS

=head2 get_template(CONFIG1, CONFIG2)

Return a Template object.

=over 4

=item Parameters

=over 4

=item CONFIG1

A hashref of options to pass to Template->new
(will override any defaults).

=item CONFIG2

A hashref of options to pass to Slash::Display::Provider->new
(will override any defaults).

=back

=item Return value

A Template object.  See L<"TEMPLATE ENVIRONMENT">.

=back

=cut

require Template::Filters;

my $strip_mode = sub {
	my($context, @args) = @_;
	return sub { strip_mode($_[0], @args) };
};

my $filters = Template::Filters->new({
	FILTERS => {
		fixparam	=> \&fixparam,
		fixurl		=> \&fixurl,
		strip_attribute	=> \&strip_attribute,
		strip_code	=> \&strip_code,
		strip_extrans	=> \&strip_extrans,
		strip_html	=> \&strip_html,
		strip_literal	=> \&strip_literal,
		strip_nohtml	=> \&strip_nohtml,
		strip_plaintext	=> \&strip_plaintext,
		strip_mode	=> [ $strip_mode, 1 ]
	}
});

sub get_template {
	my($cfg1, $cfg2) = @_;
	my $cfg = {};
	$cfg1 = ref($cfg1) eq 'HASH' ? $cfg1 : {};
	$cfg2 = ref($cfg2) eq 'HASH' ? $cfg2 : {};

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		$cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		return $cfg->{template} if $cfg->{template};
	}

	my $constants = getCurrentStatic();
	my $cache_size = $constants->{cache_enabled}		# cache at all?
		? $constants->{template_cache_size}
			? $constants->{template_cache_size}	# defined cache
			: undef					# unlimited cache
		: 0;						# cache off

	return $cfg->{template} = Template->new({
		# this really has to be "1" for some stuff to work
		TRIM		=> 1,
		LOAD_FILTERS	=> $filters,
		PLUGINS		=> { Slash => 'Slash::Display::Plugin' },
		%$cfg1,
		LOAD_TEMPLATES	=> [ Slash::Display::Provider->new({
			PRE_CHOMP	=> $constants->{template_pre_chomp},
			POST_CHOMP	=> $constants->{template_post_chomp},
			CACHE_SIZE	=> $cache_size,
			%$cfg2,
		})],
	});
}

=head1 PRIVATE FUNCTIONS

=cut

#========================================================================

=head2 _populate(DATA)

Put universal data stuff into each template: constants, user, form, env.
Each can be overriden by passing a hash key of the same name to
C<slashDisplay>.

=over 4

=item Parameters

=over 4

=item DATA

A hashref to be populated.

=back

=item Return value

Populated hashref.

=back

=cut

sub _populate {
	my($data) = @_;
	$data->{constants} = getCurrentStatic()
		unless exists $data->{constants};
	$data->{user} = getCurrentUser() unless exists $data->{user};
	$data->{form} = getCurrentForm() unless exists $data->{form};
	$data->{env} = { map { (lc, $ENV{$_}) } keys %ENV }
		unless exists $data->{env}; 
}


=head1 TEMPLATE ENVIRONMENT

The template has the options PRE_CHOMP and POST_CHOMP set by default.
You can change these in the B<vars> table in your database
(template_pre_chomp, template_post_chomp).  Also
look at the template_cache_size variable for setting the cache size.
L<Template> for more information.  The cache will be disabled entirely if
cache_enabled is false.

The template provider is Slash::Display::Provider, and the plugin module
Slash::Display::Plugin can be referenced by simply "Slash".

Additional scalar ops (which are global, so they are in effect
for every Template object created, from this or any other module)
include C<uc>, C<lc>, C<ucfirst>, and C<lcfirst>,
which all do what you think.

	[% myscalar.uc %]  # return upper case myscalar

Additional list ops include C<rand>, which returns a random element
from the given list.

	[% mylist.rand %]  # return single random element from mylist

Also provided are some filters.  The C<fixurl>, C<fixparam>, and
C<strip_*> filters are just frontends to the functions of those
names in the Slash API:

	[% FILTER strip_literal %]
		I think that 1 > 2!
	[% END %]

	<A HREF="[% env.script_name %]?op=[% FILTER fixparam %][% form.op %][% END %]">

Each strip_* function in Slash::Utility is also available as a filter.
It might seem simpler to just use the functional form:

	[% FILTER strip_nohtml %][% form.something %][% END %]
	[% Slash.strip_nohtml(form.something) %]

But we might make it harder to use the Slash plugin (see L<Slash::Display::Plugin>)
in the future (perhaps only certain seclevs?), so it is best to stick with the filter,
which is probably faster, too.

=cut

require Template::Stash;

my %list_ops = (
	'rand'		=> sub {
		my $list = shift;
		return $list->[rand @$list];
	}
);

my %scalar_ops = (
	'uc'		=> sub { uc $_[0] },
	'lc'		=> sub { lc $_[0] },
	'ucfirst'	=> sub { ucfirst $_[0] },
	'lcfirst'	=> sub { lcfirst $_[0] },
);

@{$Template::Stash::LIST_OPS}  {keys %list_ops}   = values %list_ops;
@{$Template::Stash::SCALAR_OPS}{keys %scalar_ops} = values %scalar_ops;

1;

__END__


=head1 SEE ALSO

Template(3), Slash(3), Slash::Utility(3), Slash::DB(3),
Slash::Display::Plugin(3), Slash::Display::Provider(3).
