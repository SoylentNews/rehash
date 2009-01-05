# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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
use Template 2.07;

use base 'Exporter';
use vars qw($CONTEXT %FILTERS $TEMPNAME);

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(slashDisplay slashDisplayName);
our @EXPORT_OK = qw(get_template);
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

If the var "template_show_comments" is greater than 1,
the Nocomm boolean will be ignored and the HTML comments
will ALWAYS be inserted around templates (except when they
are invoked from within other templates by INCLUDE or
PROCESS).  This is NOT what you want for a public site, since
(for example) email built up from templates will have HTML
comments in it which will confuse your readers;  HTML tags
built from several templates may have HTML comments "inside"
them, breaking your HTML syntax;  etc.

=item Skin

Each template is assigned to a skin.  This skin may be
a skin defined as a site skin, or some arbitrary skin
name.  By default, the skin that is used is whatever skin
the user is in, but it can be overridden by setting this parameter.
If a template in the current skin is not found, it defaults
to skin "default".

Skin will also default first to "light" if the user is in light
mode (and fall back to "default," again, if no template for the
"light" skin exists).

A Skin value of "NONE" will cause no skin to be defined, so
"default" will be used.

=item Page

Similarly to skins, each template is assigned to a page.
This page may be a page defined in the site, or some arbitrary
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
	return unless $name;

	my $constants = getCurrentStatic();
	my $reader    = getObject('Slash::DB', { db_type => 'reader' }); 
	my $user      = getCurrentUser();

	my($origSkin, $origPage, $tempdata);
	unless (ref($name) eq 'HASH') {
		$name = slashDisplayName($name, $data, $opt);
	}

	($name, $data, $opt, $origSkin, $origPage, $tempdata) = @{$name}{qw(
		name data opt origSkin origPage tempdata
	)};

	local $TEMPNAME = 'anon';
	unless (ref $name) {
		# we don't want to have to call this here, but because
		# it is cached the performance hit is generally light,
		# and this is the only good way to get the actual name,
		# page, skin, we bite the bullet and do it
		$tempdata ||= $reader->getTemplateByName($name, [qw(tpid page skin)]);

		# might as well bail here if we can't find the template
		if (!$tempdata) {
			# restore our original values
			$user->{currentSkin}	= $origSkin;
			$user->{currentPage}	= $origPage;
			return;
		}

		$TEMPNAME = "ID $tempdata->{tpid}, " .
			"$name;$tempdata->{page};$tempdata->{skin}";
	}

	# copy parent data structure so it is not modified,
	# so it is left alone on return back to caller
	$data = $data ? { %$data } : {};

	# let us pass in a context if we have one
	my $template = $CONTEXT || get_template(0, 0, 1);

	# we only populate $err if !$ret ... still, if $err
	# is false, then we assume everything is OK
	my($err, $ret);
	my $out = '';

	{
		local $SIG{__WARN__} = \&tempWarn;

		if ($CONTEXT) {
			$ret = eval { $out = $template->include($name, $data) };
			$err = $@ if !$ret;
		} else {
			$ret = $template->process($name, $data, \$out);
			$err = $template->error if !$ret;
		}
	}

	# template_show_comments == 0		never show HTML comments
	# template_show_comments == 1		show them if !$opt->{Nocomm}
	# template_show_comments == 2		always show them - debug only!

	my $tmpl_span_attrs = "title=\"$TEMPNAME\" style=\"display:none\"";

	my $show_comm = $constants->{template_show_comments} ? 1 : 0;
	$show_comm &&= 0 if $opt->{Nocomm} && $constants->{template_show_comments} < 2;
	# still having some problems with span, disabling for now -- pudge 2008-09-23
	$out = "\n\n<!-- start template: $TEMPNAME -->\n\n$out\n\n<!-- end template: $TEMPNAME -->\n\n"
#	$out = "\n\n<span class=\"start-template\"$tmpl_span_attrs></span>\n\n$out\n\n<span class=\"end-template\"$tmpl_span_attrs></span>\n\n"
		if $show_comm;

	if ($err) {
		errorLog("$TEMPNAME : $err");
	} else {
		print $out unless $opt->{Return};
	}

	# restore our original values
	$user->{currentSkin}	= $origSkin;
	$user->{currentPage}	= $origPage;

	return $opt->{Return} ? $out : $ret;
}

#========================================================================

sub slashDisplayName {
	my($name, $data, $opt) = @_;
	return unless $name;

	my $constants = getCurrentStatic();
	my $reader    = getObject('Slash::DB', { db_type => 'reader' }); 
	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();

	# save for later (local() seems not to work ... ?)
	my $origSkin = $user->{currentSkin} || $gSkin->{name};
	my $origPage = $user->{currentPage};

	# allow slashDisplay(NAME, DATA, RETURN) syntax
	if (! ref $opt) {
		$opt = ($opt && $opt == 1) ? { Return => 1 } : {};
	}

	if ($opt->{Skin} && $opt->{Skin} eq 'NONE') {
		$user->{currentSkin} = 'default';
	} elsif ($opt->{Skin}) {
		$user->{currentSkin} = $opt->{Skin};
	}

	if ($opt->{Page} && $opt->{Page} eq 'NONE') {
		$user->{currentPage} = 'misc';
	} elsif ($opt->{Page}) {
		$user->{currentPage} = $opt->{Page};
	}

	for (qw[currentSkin currentPage]) {
		$user->{$_} = defined $user->{$_} ? $user->{$_} : '';
	}

	my $tempdata;
	$tempdata = $reader->getTemplateByName($name, [qw(tpid page skin)])
		if $opt->{GetName};

	return {
		name        => $name,
		data        => $data,
		opt         => $opt,
		origSkin    => $origSkin,
		origPage    => $origPage,
		tempdata    => $tempdata,
	};
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
%FILTERS = (
	decode_entities		=> \&decode_entities,
	fixparam		=> \&fixparam,
	fixurl			=> \&fixurl,
	fudgeurl		=> \&fudgeurl,
	strip_paramattr		=> \&strip_paramattr,
	strip_paramattr_nonhttp	=> \&strip_paramattr_nonhttp,
	strip_urlattr		=> \&strip_urlattr,
	strip_anchor		=> \&strip_anchor,
	strip_attribute		=> \&strip_attribute,
	strip_code		=> \&strip_code,
	strip_extrans		=> \&strip_extrans,
	strip_html		=> \&strip_html,
	strip_literal		=> \&strip_literal,
	strip_nohtml		=> \&strip_nohtml,
	strip_notags		=> \&strip_notags,
	strip_plaintext		=> \&strip_plaintext,
	strip_mode		=> [ $strip_mode, 1 ],
	%FILTERS
);

my $filters = Template::Filters->new({ FILTERS => \%FILTERS });

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
include C<int>, C<abs>, C<uc>, C<lc>, C<ucfirst>, and C<lcfirst>,
which all do what you think.

	[% myscalar.uc %]  # return upper case myscalar

C<substr> accepts 1 or 2 args, for the two corresponding forms of the
perl function C<substr>.

	[% myscalar.substr(2)    # all but first two characters %]
	[% myscalar.substr(2, 1) # third character %]

Additional list ops include C<rand>, C<lowval>, C<highval>,
C<grepn> and C<remove>.

C<rand> returns a random value from the list.

	[% mylist.rand %]  # return single random element from mylist

C<lowval>, and C<highval> do exacly what they sound like, they return the 
lowest or the highest value in the list.

C<grepn> returns the position of the first occurance of a given value. See 
C<Slash::Utility::grepn>.

C<remove> returns the list with all entries matching the given parameter,
removed.

	[% b = (0, 1, 0, 2, 0, 3, 0, 5);
	   b.remove(0).join(',') %]		# Outputs: "1,2,3,5"

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

sub _ref { ref $_[0] }

my %hash_ops = (
	'ref'		=> \&_ref,
);

my %list_ops = (
	'ref'		=> \&_ref,
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

	'grepn'		=> sub {
		my($list, $search_val) = @_;
		
		return grepn($list, $search_val);
	},

	'remove'	=> sub {
		my($list, $remove_val) = @_;
		return [ grep { $_ ne $remove_val } @$list ];
	},
);

my %scalar_ops = (
	'ref'		=> \&_ref,
	'int'		=> sub { int $_[0] },
	'abs'		=> sub { abs $_[0] },
	'uc'		=> sub { uc $_[0] },
	'lc'		=> sub { lc $_[0] },
	'ucfirst'	=> sub { ucfirst $_[0] },
	'lcfirst'	=> sub { lcfirst $_[0] },
	'gt'		=> sub { $_[0] gt $_[1] },
	'lt'		=> sub { $_[0] lt $_[1] },
	'cmp'		=> sub { $_[0] cmp $_[1] },
	'substr'        => sub {
		if (@_ == 2) {
			substr($_[0], $_[1]);
		} elsif (@_ == 3) {
			substr($_[0], $_[1], $_[2])
		} else {
			return $_[0];
		}
	},
	'rand'		=> sub {
		my $maxval = $_[0] || 1;
		return rand($maxval);
	},
	# integer value to Systeme Internationale (K=kilo, M=mega, etc.)
	size2si		=> sub {
		my $v = $_[0] || 0;
		my $a = $v < 0 ? -$v : $v;
		my @formats = qw(  %d  %.1fK  %.1fM  %.1fG  %.1fT  );
		while (my $format = shift @formats) {
			return sprintf($format, $v) if $a < 2*1024 || !@formats;
			$a /= 1024; $v /= 1024;
		}
		return "size2si_err";
	},
);

@{$Template::Stash::HASH_OPS}  {keys %hash_ops}   = values %hash_ops;
@{$Template::Stash::LIST_OPS}  {keys %list_ops}   = values %list_ops;
@{$Template::Stash::SCALAR_OPS}{keys %scalar_ops} = values %scalar_ops;

#========================================================================

sub tempWarn {
	my @lines = @_;
	if ($lines[0] !~ /Use of uninitialized value/) {
		if ($lines[0] =~ /at \(eval \d+\)/) {
			chomp($lines[0]);
			$lines[0] =~ s/\.$//;
			$lines[0] .= " in template $TEMPNAME\n";
		}
		warn @lines;
	}
}

1;

__END__


=head1 SEE ALSO

Template(3), Slash(3), Slash::Utility(3), Slash::DB(3),
Slash::Display::Plugin(3), Slash::Display::Provider(3).
