# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tools;

use strict;
use warnings;

use Carp;
use DB_File;
use Fcntl qw(O_RDWR O_CREAT);
use File::Find;

use base 'Exporter';

our @EXPORT = qw(
	pmpath pathpm pmpathsrc syntax_check counterpart
);

my(%cache);
our %config = (
	source  => '/usr/local/src/slash',
	install => '/usr/local/slash',
	cache   => "$ENV{HOME}/.slash_tools_cache",
	config  => "$ENV{HOME}/.slash_tools_config",
	force   => 0
);

sub import {
	my $proto = shift;
        my $class = ref $proto || $proto;

	my %newconfig = @_;
	if (open my $fh, '<', $newconfig{config} || $config{config}) {
		while (<$fh>) {
			next if /^\W/;
			chomp;
			my @a = split ' ', $_, 2;
			$config{$a[0]} = $a[1] if $a[0] && $a[1];
		}
	}

	# handle config inputs, which means we are ignoring normal
	# import behavior ... you get everything, which is not really
	# playing nice, but oh well! -- pudge
	%config = ( %config, %newconfig );

	tie %cache, 'DB_File', $config{cache}, O_RDWR|O_CREAT, 0644, $DB_HASH
		or croak "Can't tie to $config{cache}: $!";

	local $Exporter::ExportLevel = 1;
	return $class->SUPER::import;
}


sub syntax_check {
	my($file) = @_;
	my $check = `$^X -wc \Q$file\E 2>&1`;
	if ($check =~ / syntax OK$/) {
		undef $@;
		return 1;
	} else {
		$@ = $check;
		return 0;
	}
}

sub counterpart {
	my($this, $force) = @_;
	my $counterpart;

	my $key = join $;, 'pathpm', $config{source}, $config{install}, $this;
	$force = $config{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	if ($this =~ /\.pm$/) {
		if ($this =~ /^\Q$config{source}\E/) {
			$counterpart = pmpath(pathpm($this, $force), $force);
		} else {
			$counterpart = pmpathsrc(pathpm($this, $force), $force);
		}
	} else {
		if ($this =~ /^\Q$config{source}\E/) {
			($counterpart = $this) =~ s/^\Q$config{source}\E/$config{install}/;
		} else {
			($counterpart = $this) =~ s/^\Q$config{install}\E/$config{source}/;
		}
	}

	$cache{$key} = $counterpart if $counterpart;

	return $counterpart;
}

sub _getpackage {
	my($path) = @_;

	if (open my $fh, '<', $path) {
		my $code = do { local $/; <$fh> };
		while ($code =~ /^\s*package\s+([A-Za-z0-9_:]+)\s*;/mg) {
			next if $1 eq 'main';
			return $1;
		}
	} else {
		warn "Can't open $path: $!";
		return;
	}

}

# convert a path to a perl module
sub pathpm {
	my($path, $force) = @_;
	return unless $path;

	my $key = join $;, 'pathpm', $path;
	$force = $config{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	my $package = _getpackage($path);
	$cache{$key} = $package if $package;

	return $package;
}

# convert a perl module to a src path
sub pmpathsrc {
	my($module, $force) = @_;
	return unless defined $module;

	my $key = join $;, 'pmpathsrc', $config{source}, $module;
	$force = $config{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	(my $modname = $module) =~ s/^.+::(\w+)$/$1/;
	$modname .= '.pm';

	my $found;
	find(sub {
		return if $found;
		return unless $_ eq $modname;
		my $name = $File::Find::name;

		my $package = _getpackage($name);
		$cache{$key} = $found = $name if $package;
	}, $config{source});

	return $found;
}

# convert a perl module to an installed path
sub pmpath {
	my($module, $force) = @_;
	return unless defined $module;

	my $key = join $;, 'pmpath', $module;
	$force = $config{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	(my $path = $module) =~ s{::}{/}g;
	(my $name = $module) =~ s/^.+::(\w+)$/$1/;
	my $pathmod = $path . '.pm';

	if ($INC{$pathmod}) {
		$cache{$key} = $INC{$pathmod};
		return $INC{$pathmod};
	}

	my $return;
	eval "require $module";
	if ($@) {
		# find from perl error
		if      ($@ =~ m{\s['"]?(\S+/$pathmod)}) {
			$return = $1;
		# find from shared library error
		} elsif ($@ =~ m{\s['"]?(\S+/)auto/$path(/$name)?\.\w+}) {
			$return = "$1$pathmod";
		}

		if (!$return || ! -e $return) {
			carp "path for '$module' not found, error: $@\n";
		} else {
			$cache{$key} = $return;
		}
	} else {
		if ($INC{$pathmod}) {
			$cache{$key} = $return = $INC{$pathmod};
		} else {
			carp "path for '$module' unavailable in %INC\n";
		}
	}

	return $return;
}

1;


__END__

Example config file:

source		/usr/local/src/gittest/slash
install		/usr/local/slash


Example code:

use Slash::Tools;

# find all files in src that are not installed
use File::Find;
find(sub {
	return if /^\./;
	my $name = $File::Find::name;
	return if $name =~ m{/CVS/} || $name =~ m{/\.};
	return unless -f $name;

	my $counterpart = counterpart($name) || '';
	printf "%s => %s\n", $name, $counterpart
		if !$counterpart || !-e $counterpart;
}, $Slash::Tools::config{source});


# do syntax checks of modules
for ('Slash::Constants', 'Slash::Utility', 'Slash::Utility::Access',
	'Slash::Apache', 'Slash::Apache', 'Slash::Apache::User',
	'Slash::SearchToo::KinoSearch', 'Slash',
	'Slash::XML', 'Slash::Custom::Bulkmail', 'Slash::XML::OAI') {
	syntax_check(pmpath($_)) or warn $@;
}

# counterpart sanity checks:
my $file = pmpath('Slash::XML::Atom');
print "Yay, doesn't match!\n" if $file ne counterpart($file);
print "Yay, matches!\n" if $file eq counterpart(counterpart($file));
