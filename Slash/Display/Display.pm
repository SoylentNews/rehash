# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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
use Slash::Display::Provider ();
use Slash::Utility::Data;
use Slash::Utility::Environment;
use Slash::Utility::System;
use Template 2.06;

use base 'Exporter';
use vars qw($VERSION @EXPORT @EXPORT_OK $CONTEXT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(slashDisplay);
@EXPORT_OK = qw(get_template);
my(%objects);

# FRY: That doesn't look like an L at all. Unless you count lowercase.

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
Default passed parameters include constants, env, user, anon,
and form.  These cannot be overriden.

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
block this is.  Default is to include comments if the var
"template_show_comments" is true, to not include comments
if it is false.  It is true by default.

=item Section

Each template is assigned to a section.  This section may be
a section defined as a site section, or some arbitrary section
name.  By default, the section that is used is whatever section
the user is in, but it can be overridden by setting this parameter.
If a template in the current section is not found, it defaults
to section "default".

Section will also default first to "light" if the user is in light
mode (and fall back to "default," again, if no template for the
"light" section exists).

A Section value of "NONE" will cause no section to be defined, so
"default" will be used.

=item Page

Similarly to sections, each template is assigned to a page.
This section may be a page defined in the site, or some arbitrary
page name.  By default, the page that is used is whatever page
the user is on (such as "users" for "users.pl"), but it can be
overridden by setting this parameter.  If a template in the current
page is not found, it defaults to page "misc".

A Page value of "NONE" will cause no page to be defined, so
"misc" will be used.

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
	my(@comments, $err, $ret, $out, $origSection, $origPage,
		$tempdata, $tempname, $user, $slashdb, $constants);
	return unless $name;

	$constants = getCurrentStatic();
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

	# let us pass in a context if we have one
	my $template = $CONTEXT || get_template(0, 0, 1);

	# we only populate $err if !$ret ... still, if $err
	# is false, then we assume everything is OK
	if ($CONTEXT) {
		$ret = eval { $out = $template->include($name, $data) };
		$err = $@ if !$ret;
	} else {
		$ret = $template->process($name, $data, \$out);
		$err = $template->error if !$ret;
	}

	my $Nocomm = defined $opt->{Nocomm}
		? $opt->{Nocomm}
		: !$constants->{template_show_comments};

	$out = $comments[0] . $out . $comments[1] unless $Nocomm;

	if ($err) {
		errorLog("$tempname : $err");
	} else {
		print $out unless $opt->{Return};
	}

	# restore our original values
	$user->{currentSection}	= $origSection;
	$user->{currentPage}	= $origPage;

	return $opt->{Return} ? $out : $ret;
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

# Note that the strip_anchor filter really isn't all
# that necessary if you know how to edit templates.
# However, it's better if you have a specific style 
# for a template and you don't want your tags running
# up against each other.		- Cliff 8/1/01
my $filters = Template::Filters->new({
	FILTERS => {
		fixparam	=> \&fixparam,
		fixurl		=> \&fixurl,
		fudgeurl	=> \&fudgeurl,
		strip_anchor	=> \&strip_anchor,
		strip_attribute	=> \&strip_attribute,
		strip_code	=> \&strip_code,
		strip_extrans	=> \&strip_extrans,
		strip_html	=> \&strip_html,
		strip_literal	=> \&strip_literal,
		strip_nohtml	=> \&strip_nohtml,
		strip_notags	=> \&strip_notags,
		strip_plaintext	=> \&strip_plaintext,
		strip_mode	=> [ $strip_mode, 1 ]
	}
});

sub get_template {
	my($cfg1, $cfg2, $VirtualUser) = @_;
	$VirtualUser &&= getCurrentVirtualUser();

	my $cfg;
	$cfg1 = ref($cfg1) eq 'HASH' ? $cfg1 : {};
	$cfg2 = ref($cfg2) eq 'HASH' ? $cfg2 : {};

	# think more on this, consider putting it in
	# Slash::Utility::Environment -- pudge
	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		$cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		return $cfg->{template} if $cfg->{template};
	} elsif ($VirtualUser && ref $objects{$VirtualUser}) {
		return $objects{$VirtualUser};
	}

	my $constants = getCurrentStatic();
	my $cache_size = $constants->{cache_enabled}		# cache at all?
		? $constants->{template_cache_size}
			? $constants->{template_cache_size}	# defined cache
			: undef					# unlimited cache
		: 0;						# cache off

	my $template = Template->new({
		# this really has to be "1" for some stuff to work
		TRIM		=> 1,
		LOAD_FILTERS	=> $filters,
		PLUGINS		=> { Slash => 'Slash::Display::Plugin' },
		%$cfg1,
		LOAD_TEMPLATES	=> [ Slash::Display::Provider->new({
			FACTORY		=> 'Slash::Display::Directive',
			PRE_CHOMP	=> $constants->{template_pre_chomp},
			POST_CHOMP	=> $constants->{template_post_chomp},
			CACHE_SIZE	=> $cache_size,
			%$cfg2,
		})],
	});

	$cfg->{template}	= $template if ref $cfg;
	$objects{$VirtualUser}	= $template if $VirtualUser;

	return $template;
}

=head1 TEMPLATE ENVIRONMENT

=head2 Preferences

The template has the options PRE_CHOMP and POST_CHOMP set by default.
You can change these in the B<vars> table in your database
(template_pre_chomp, template_post_chomp).  Also
look at the template_cache_size variable for setting the cache size.
L<Template> for more information.  The cache will be disabled entirely if
cache_enabled is false.

=head2 Plugin

The template provider is Slash::Display::Provider, and the plugin module
Slash::Display::Plugin can be referenced by simply "Slash".

=head2 Additional Ops

Additional scalar ops (which are global, so they are in effect
for every Template object created, from this or any other module)
include C<uc>, C<lc>, C<ucfirst>, and C<lcfirst>,
which all do what you think.

	[% myscalar.uc %]  # return upper case myscalar

C<substr> accepts 1 or 2 args, for the two corresponding forms of the
perl function C<substr>.

	[% myscalar.substr(2)    # all but first two characters %]
	[% myscalar.substr(2, 1) # third character %]

Additional list ops include C<rand>, which returns a random element
from the given list.

	[% mylist.rand %]  # return single random element from mylist

=head2 Additional Filters

Also provided are some filters.  The C<fixurl>, C<fixparam>, C<fudgeurl>,
and C<strip_*> filters are just frontends to the functions of those
names in the Slash API:

	[% FILTER strip_literal %]
		I think that 1 > 2!
	[% END %]

See L<Slash::Utility::Data> for a complete list of available C<strip_*>
filters, and descriptions of each.

Note that [% var | filter %] is a synonym for [% FILTER filter; var; END %]:

	<A HREF="[% env.script_name %]?op=[% form.op | fixparam %]">

It might seem simpler to just use the functional form:

	[% form.something | strip_nohtml      # filter %]
	[% Slash.strip_nohtml(form.something) # function %]

But we might make it harder to use the Slash plugin (see
L<Slash::Display::Plugin>) in the future (perhaps only certain seclevs?), so it
is best to stick with the filter, which is most likely faster anyway.

=cut

my %list_ops = (
	'rand'		=> sub {
		my $list = $_[0];
		return $list->[rand @$list];
	},

	'highval'	=> sub {
		my $list = $_[0];
		my($maxval) = sort { $b <=> $a } @$list;
		return $maxval;
	},

	'lowval'	=> sub {
		my $list = $_[0];
		my($minval) = sort { $a <=> $b } @$list;
		return $minval;
	},
);

my %scalar_ops = (
	'uc'		=> sub { uc $_[0] },
	'lc'		=> sub { lc $_[0] },
	'ucfirst'	=> sub { ucfirst $_[0] },
	'lcfirst'	=> sub { lcfirst $_[0] },

	'substr'        => sub {
		if (@_ == 2) {
			substr($_[0], $_[1]);
		} elsif (@_ == 3) {
			substr($_[0], $_[1], $_[2])
		} else {
			return $_[0];
		}
	},
);

@{$Template::Stash::LIST_OPS}  {keys %list_ops}   = values %list_ops;
@{$Template::Stash::SCALAR_OPS}{keys %scalar_ops} = values %scalar_ops;

1;

__END__


=head1 SEE ALSO

Template(3), Slash(3), Slash::Utility(3), Slash::DB(3),
Slash::Display::Plugin(3), Slash::Display::Provider(3).
