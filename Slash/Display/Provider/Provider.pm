# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Display::Provider;

=head1 NAME

Slash::Display::Provider - Template Toolkit provider for Slash

=head1 SYNOPSIS

	use Slash::Display::Provider;
	my $template = Template->new(
		LOAD_TEMPLATES	=> [ Slash::Display::Provider->new ]
	);


=head1 DESCRIPTION

This here module provides templates to a Template Toolkit processor
by way of the Slash API (which basically means that it grabs templates
from the templates table in the database).  It caches them, too.  It also
can process templates passed in as text, like the base Provider module,
but this one will create a unique name for the "anonymous" template so
it can be cached.  Overriden methods include C<fetch>, C<_load>,
and C<_refresh>.

=cut

use strict;
use vars qw($DEBUG);
use base qw(Template::Provider);
use File::Spec::Functions;
use Slash::Utility::Environment;

our $VERSION = $Slash::Constants::VERSION;
$DEBUG       = $Template::Provider::DEBUG || 0 unless defined $DEBUG;

# BENDER: Oh, no room for Bender, huh?  Fine.  I'll go build my own lunar
# lander.  With blackjack.  And hookers.  In fact, forget the lunar lander
# and the blackjack!  Ah, screw the whole thing.

use constant PREV => 0;
use constant NAME => 1;
use constant DATA => 2;
use constant LOAD => 3;
use constant NEXT => 4;

# store names for non-named templates by using text of template as
# hash key; that it is not VirtualHost-specific is not a problem;
# this just does a name lookup, and the actual template is compiled
# and stored in the VirtualHosts' template objects
{
	my($anon_num, %anon_template);
	sub _get_anon_name {
		my($text) = @_;
		return $anon_template{$text} if exists $anon_template{$text};
		return $anon_template{$text} = 'anon_' . ++$anon_num;
	}
}

sub fetch {
	my($self, $text) = @_;
	my($name, $data, $error, $slot, $size, $compname, $compfile);
	$size = $self->{ SIZE };

	# if reference, then get a unique name to cache by
	if (ref $text eq 'SCALAR') {
		$text = $$text;
		print STDERR "fetch text : $text\n" if $DEBUG > 2;
		$name = _get_anon_name($text);
		$compname = $name if $self->{COMPILE_DIR};

	# if regular scalar, get proper template ID ("name") from DB
	} else {
		print STDERR "fetch text : $text\n" if $DEBUG > 1;
		my $reader = getObject('Slash::DB', { db_type => 'reader' }); 

		my $temp = $reader->getTemplateByName($text, [qw(tpid page skin)]);
		$compname = "$text;$temp->{page};$temp->{skin}"
			if $self->{COMPILE_DIR};
		$name = $temp->{tpid};
		undef $text;
	}

	if ($self->{COMPILE_DIR}) {
		my $ext = $self->{COMPILE_EXT} || '.ttc';
		$compfile = catfile($self->{COMPILE_DIR}, $compname . $ext);
		warn "compiled output: $compfile\n" if $DEBUG;
	}

	# caching disabled so load and compile but don't cache
	if (defined $size && !$size) {
		print STDERR "fetch($name) [nocache]\n" if $DEBUG;
		($data, $error) = $self->_load($name, $text);
		($data, $error) = $self->_compile($data, $compfile) unless $error;
		$data = $data->{ data } unless $error;

	# cached entry exists, so refresh slot and extract data
	} elsif ($name && ($slot = $self->{ LOOKUP }{ $name })) {
		print STDERR "fetch($name) [cached:$size]\n" if $DEBUG;
		($data, $error) = $self->_refresh($slot);
		$data = $slot->[ DATA ] unless $error;

	# nothing in cache so try to load, compile and cache
	} else {
		print STDERR "fetch($name) [uncached:$size]\n" if $DEBUG;
		($data, $error) = $self->_load($name, $text);
		($data, $error) = $self->_compile($data, $compfile) unless $error;
		$data = $self->_store($name, $data) unless $error;
	}

	return($data, $error);
}

sub _load {
	my($self, $name, $text) = @_;
	my($data, $error, $now, $time);
	$now = time;
	$time = 0;

	print STDERR "_load(@_[1 .. $#_])\n" if $DEBUG;

	if (! defined $text) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' }); 
		# in arrayref so we also get _modtime
		my $temp = $reader->getTemplate($name, ['template']);
		$text = $temp->{template};
		$time = $temp->{_modtime};
	}

	# just in case ... most data from DB will be in CRLF, doesn't
	# hurt to do this quick s///
	$text =~ s/\015\012/\n/g;

	$data = {
		name	=> $name,
		text	=> $text,
		'time'	=> $time,
		load	=> $now,
	};

	return($data, $error);
}

# hm, refresh is almost what we want, except we want to override
# the logic for deciding whether to reload ... can that be determined
# without reimplementing the whole method?
sub _refresh {
	my($self, $slot) = @_;
	my($head, $file, $data, $error);

	print STDERR "_refresh([ @$slot ])\n" if $DEBUG;

	# compare load time with current _modtime from API to see if
	# it's modified and we need to reload it
	if ($slot->[ DATA ]{modtime}) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' }); 
		my $temp = $reader->getTemplate($slot->[ NAME ], ['tpid']);

		if ($slot->[ DATA ]{modtime} < $temp->{_modtime}) {
			print STDERR "refreshing cache file ", $slot->[ NAME ], "\n"
				if $DEBUG;

			($data, $error) = $self->_load($slot->[ NAME ]);
			($data, $error) = $self->_compile($data) unless $error;
			$slot->[ DATA ] = $data->{ data } unless $error;
		}
	}

	# i know it is not a huge amount of cycles, but i wish
	# we didn't have to bother with LRU stuff if SIZE is undef,
	# but we don't want to break other methods that also use it

	# remove existing slot from usage chain...
	if ($slot->[ PREV ]) {
		$slot->[ PREV ][ NEXT ] = $slot->[ NEXT ];
	} else {
		$self->{ HEAD } = $slot->[ NEXT ];
	}

	if ($slot->[ NEXT ]) {
		$slot->[ NEXT ][ PREV ] = $slot->[ PREV ];
	} else {
		$self->{ TAIL } = $slot->[ PREV ];
	}

	# ... and add to start of list
	$head = $self->{ HEAD };
	$head->[ PREV ] = $slot if $head;
	$slot->[ PREV ] = undef;
	$slot->[ NEXT ] = $head;
	$self->{ HEAD } = $slot;

	return($data, $error);
}


# this may be its own module someday if it grows at all
package Slash::Display::Directive;

use base qw(Template::Directive);
use Slash::Utility::Environment;

# this is essentially the same as Template::Directive, but we want
# to hijack simple calls to $constants to optimize it
# I imagine this is still faster than using Stash::XS ... -- pudge
sub ident {
	my ($class, $ident) = @_;
	return "''" unless @$ident;

	my $types = qr/^'(constants|form|user|anon)'$/;
	if ($ident->[0] =~ $types && (my $type = $1) && @$ident == 4 && $ident->[2] =~ /^'(.+)'$/s) {
		(my $data = $1) =~ s/'/\\'/;
		return "\$${type}->{'$data'}";
	# env
	} elsif ($ident->[0] eq q['env'] && @$ident == 4 && $ident->[2] =~ /^'(.+)'$/s) {
		(my $data = $1) =~ s/'/\\'/;
		return qq[\$ENV{"\\U$data"}];
	# fg/bg
	} elsif ($ident->[0] eq q['user'] && @$ident == 6 && $ident->[2] =~ /^'(fg|bg)'$/s) {
		return "\$user->{'$1'}[$ident->[4]]";
	}

	if (scalar @$ident <= 2 && ! $ident->[1]) {
		$ident = $ident->[0];
	} else {
		$ident = '[' . join(', ', @$ident) . ']';
	}
	return "\$stash->get($ident)";
}

# we don't want multiple USEs for the Slash
sub use {
	if ($_[1]->[0][0] eq q"'Slash'") {
		return;
	} else {
		return Template::Directive::use(@_);
	}
}

sub template {
	my($class, $block) = @_;
	$block = pad($block, 2) if $Template::Directive::PRETTY;

	return "sub { return '' }" unless $block =~ /\S/;

	my $extra = <<'EOF';
my $anon = Slash::getCurrentAnonymousCoward();
my $user = Slash::getCurrentUser();
my $form = Slash::getCurrentForm();
my $constants = Slash::getCurrentStatic();
my $gSkin = Slash::getCurrentSkin();

$stash->set('Slash', $context->plugin('Slash'));
$stash->set('anon', $anon);
$stash->set('user', $user);
$stash->set('form', $form);
$stash->set('constants', $constants);
$stash->set('gSkin', $gSkin);
$stash->set('env', { map { (lc, $ENV{$_}) } keys %ENV });
EOF

	my $template = <<EOF;
sub {
    my \$context = shift || die "template sub called without context\\n";
    my \$stash   = \$context->stash;
    my \$output  = '';
    my \$error;

    eval { BLOCK: {
$extra
$block
    } };
    if (\$@) {
        \$error = \$context->catch(\$@, \\\$output);
	die \$error unless \$error->type eq 'return';
    }

    return \$output;
}
EOF

	return $template;
}


1;

__END__


=head1 SEE ALSO

Template(3), Template::Provider(3), Slash(3), Slash::Utility(3),
Slash::Display(3).
