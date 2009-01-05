# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tools;

use strict;
use warnings;

use Carp;
use DB_File;
use Fcntl qw(O_RDWR O_CREAT);
use File::Basename qw(basename dirname);
use File::Find;

use base 'Exporter';

our %config;
our $VERSION = '2.005001';
our @EXPORT = qw(
	pmpath pathpm pmpathsrc counterpart srcfile installfile basefile
	basefile basename dirname
	syntax_check %CONFIG
	@BIN_EXT $BIN_EXT $BIN_RE
	myprint myexit mysystem myask
);

our @BIN_EXT = qw(gz tgz bz2 gif jpg png ico);
our $BIN_EXT = join '|', @BIN_EXT;
our $BIN_RE  = qr/\.(?:$BIN_EXT)$/;

my(%cache);
# if cache gets stale, you can use force => 0, or heck, just
# rm ~/.slash_tools_cache
our %CONFIG = (
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
	if (open my $fh, '<', $newconfig{config} || $CONFIG{config}) {
		while (<$fh>) {
			next if /^\W/;
			chomp;
			my @a = split ' ', $_, 2;
			$CONFIG{$a[0]} = $a[1] if $a[0] && $a[1];
		}
	}

	# handle config inputs, which means we are ignoring normal
	# import behavior ... you get everything, which is not really
	# playing nice, but oh well! -- pudge
	%CONFIG = ( %CONFIG, %newconfig );

	tie %cache, 'DB_File', $CONFIG{cache}, O_RDWR|O_CREAT, 0644, $DB_HASH
		or croak "Can't tie to $CONFIG{cache}: $!";

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

# return the base file of the requested file (relative to src)
sub basefile {
	my($file, $force) = @_;
	if ($file !~ /^\Q$CONFIG{source}\E/) {
		$file = counterpart($file, $force);
	}
	$file =~ s/^\Q$CONFIG{source}\/\E//;
	return $file;
}


# return the src file of the requested file
sub srcfile {
	my($file, $force) = @_;
	if ($file !~ /^\Q$CONFIG{source}\E/) {
		return counterpart($file, $force);
	}
	return $file;
}

# return the installed file of the requested file
sub installfile {
	my($file, $force) = @_;
	if ($file =~ /^\Q$CONFIG{source}\E/) {
		return counterpart($file, $force);
	}
	return $file;
}

sub counterpart {
	my($this, $force) = @_;
	my $counterpart;

	my $key = join $;, 'pathpm', $CONFIG{source}, $CONFIG{install}, $this;
	$force = $CONFIG{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	if ($this =~ /\.pm$/) {
		if ($this =~ /^\Q$CONFIG{source}\E/) {
			$counterpart = pmpath(pathpm($this, $force), $force);
		} else {
			$counterpart = pmpathsrc(pathpm($this, $force), $force);
		}
	} else {
		if ($this =~ /^\Q$CONFIG{source}\E/) {
			($counterpart = $this) =~ s/^\Q$CONFIG{source}\E/$CONFIG{install}/;
		} else {
			($counterpart = $this) =~ s/^\Q$CONFIG{install}\E/$CONFIG{source}/;
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
		carp "Can't open $path: $!";
		return;
	}

}

# convert a path to a perl module
sub pathpm {
	my($path, $force) = @_;
	return unless $path;

	my $key = join $;, 'pathpm', $path;
	$force = $CONFIG{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	my $package = _getpackage($path);
	$cache{$key} = $package if $package;

	return $package;
}

# convert a perl module to a src path
sub pmpathsrc {
	my($module, $force) = @_;
	return unless defined $module;

	my $key = join $;, 'pmpathsrc', $CONFIG{source}, $module;
	$force = $CONFIG{force} unless defined $force;
	return $cache{$key} if !$force && $cache{$key};

	(my $modname = $module) =~ s/^.+::(\w+)$/$1/;
	$modname .= '.pm';

	my $found;
	find(sub {
		return if $found;
		return unless $_ eq $modname;
		my $name = $File::Find::name;

		my $package = _getpackage($name);
		$cache{$key} = $found = $name if $package && $package eq $module;
	}, $CONFIG{source});

	return $found;
}

# convert a perl module to an installed path
sub pmpath {
	undef $@;
	my($module, $force) = @_;
	return unless defined $module;

	my $key = join $;, 'pmpath', $module;
	$force = $CONFIG{force} unless defined $force;
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
			carp "install path for '$module' not found";
		} else {
			$cache{$key} = $return;
		}
	} else {
		if ($INC{$pathmod}) {
			$cache{$key} = $return = $INC{$pathmod};
		} else {
			carp "path for '$module' unavailable in %INC";
		}
	}

	return $return;
}

sub myprint {
	print        join "\n", @_, '' if @_;
}

sub myexit {
	print STDERR join "\n", @_, '' if @_;
	exit;
}

sub myask {
	local $| = 1;
	print        join "\n", @_, '' if @_;
	print "Continue? [Yn] ";
	my $ans = <>;
	return $ans =~ /^n/i ? 0 : 1;
}

sub mysystem {
	#print "@_\n";
	system(@_);
}

package Slash::Tools::BBEdit;
use Carp;
use Cwd;
use File::Basename;

sub new {
	require Mac::Glue;
	bless { glue => Mac::Glue->new('BBEdit') }, __PACKAGE__;
}

sub front {
	my($self) = @_;
	return $self->{glue}->obj(window => 1)->get;
}

sub frontpath {
	my($self) = @_;
	return $self->front->prop('file')->get;
}

sub output {
	my($self, $output, $opt) = @_;

	my $title = $opt->{title} || 'Slash Tools Output';
	open my $bbedit, qq'|bbedit --view-top --clean -t "$title"' or carp $!;
	print $bbedit $output;
}

sub file {
	my($self) = @_;

	my $file = $ARGV[0];
	unless ($file) {
		$file = $self->frontpath;
	}

	return $file;
}

sub do_prep {
	my($self) = @_;

	my $file = $self->file;
	return unless $file;

	my $cwd = cwd();
	chdir dirname(Slash::Tools::srcfile($file));

	return(basename($file), $cwd);
}

sub do {
	my($self, $cmd, $opt) = @_;

	my($file, $orig_cwd) = $self->do_prep;
	my $basename = basename($file);

	my $output = `$cmd \Q$file\E`;
	if ($output) {
		$self->output($output, { title => "$cmd $basename" });
		$self->front->prop('source_language')->set(to => $opt->{type})
			if $opt->{type};
		$self->front->prop('source_language')->set(to => '(none)')
			if $opt->{notype};
	}

	chdir $orig_cwd;
}

sub gitdiff {
	my($self, $args) = @_;

	my($file, $orig_cwd) = $self->do_prep;

	local $ENV{GIT_EXTERNAL_DIFF} = 'bbdiff-git';
	system('git', 'diff', split(' ', $args), '--', $file);

	chdir $orig_cwd;
}

sub diff {
	my($self, $args, $file) = @_;

	$file ||= $self->file;
	my $src_file = Slash::Tools::srcfile($file);
	my $install_file = Slash::Tools::installfile($file);

	if (-f $src_file && -f $install_file) {
		system('bbdiff', split(' ', ($args||'')), $install_file, $src_file);
	} else {
		carp "$src_file or $install_file does not exist";
	}
}


package Slash::Tools::Mac;

sub new {
	require MacPerl;
	shift;
	my $self = bless { @_ }, __PACKAGE__;
	$self->{creator} ||= 'R*ch';
	$self;
}

sub set_type {
	my $self = shift;
	return unless $self->{creator};

	my($file) = @_;
	return if $file =~ $BIN_RE;

	my($creator, $type) = MacPerl::GetFileInfo($file);
	return if $creator && $type && $creator eq $self->{creator} && $type eq 'TEXT';

	MacPerl::SetFileInfo($self->{creator}, 'TEXT', $file);
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
}, $CONFIG{source});


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
