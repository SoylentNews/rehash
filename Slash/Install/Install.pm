# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Install;
use strict;
use vars qw($VERSION @ISA);
use DBIx::Password;
use Slash;
use Slash::DB::Utility;
use Slash::DB;
use File::Copy;
use File::Find;
use File::Path;

# BENDER: Like most of life's problems, this one can be solved with bending.

@ISA       = qw(Slash::DB::Utility);
($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my ($class, $user) = @_;
	my $self = {};
	bless ($self,$class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;
	$self->{slashdb} = Slash::DB->new($user);

	return $self;
}

sub create {
	my ($self, $values) = @_;
	$self->sqlInsert('site_info', $values);
}

sub delete {
	my ($self, $key) = @_;
	my $sql = "DELETE from site_info WHERE name = " . $self->sqlQuote($key);
	$self->sqlDo($sql);
}

sub deleteByID  {
	my ($self, $key) = @_;
	my $sql = "DELETE from site_info WHERE param_id=$key";
	$self->sqlDo($sql);
}

sub get{
	my ($self, $key) = @_;
	my $count = $self->sqlCount('site_info', "name=" . $self->sqlQuote($key));
	my $hash;
	if($count > 1) {
		$hash = $self->sqlSelectAllHashref('param_id', '*', 'site_info', "name=" . $self->sqlQuote($key));
	} else {
		$hash = $self->sqlSelectHashref('*', 'site_info', "name=" . $self->sqlQuote($key));
	}

	return $hash;
}

sub exists{
	my ($self, $key, $value) = @_;
	return unless $key;
	my $where;
	$where .= "name=" . $self->sqlQuote($key);
	$where .= " AND value=" . $self->sqlQuote($value) if $value;
	my $count = $self->sqlCount('site_info', $where);

	return $count;
}

sub getValue{
	my ($self, $key) = @_;
	my $count = $self->sqlCount('site_info', "name=" . $self->sqlQuote($key));
	my $value;
	unless($count > 1) {
		($value) = $self->sqlSelect('value', 'site_info', "name=" . $self->sqlQuote($key));
	} else {
		$value = $self->sqlSelectColArrayref('value', 'site_info', "name=" . $self->sqlQuote($key));
	}

	return $value;
}

sub getByID {
	my ($self, $id) = @_;
	my $return = $self->sqlSelectHashref('*', 'site_info', "param_id = $id");

	return $return;
}

sub DESTROY {
	my ($self) = @_;
	if($self->{_dbh}) {
		$self->{_dbh}->disconnect unless ($ENV{GATEWAY_INTERFACE});
	}
}

sub readTemplateFile {
	my ($self, $filename) = @_;
	return unless(-f $filename);
	open(FILE, $filename) or die "$! unable to open file $filename to read from";
	my @file = <FILE>;
	my %val;
	my $latch;
	for(@file) {
		if (/^__(.*)__$/) {
			$latch = $1;
			next;
		}
		$val{$latch} .= $_  if $latch;
	}
	$val{'tpid'} = undef if $val{'tpid'};
	for(qw| name page section lang seclev description title |) {
		chomp($val{$_}) if $val{$_};
	}
	
	return \%val;
}

sub writeTemplateFile {
	my ($self, $filename, $template) = @_;
	open(FILE, '>' . $filename) or die "$! unable to open file $filename to write to";
	for(keys %$template) {
		next if ($_ eq 'tpid');
		print FILE "__${_}__\n";
		$template->{$_} =~ s/\015\012/\n/g;
		print FILE "$template->{$_}\n";
	}
	close(FILE);
}

sub installPlugin {
	my($self, $answers, $plugins, $symlink) = @_;
	$plugins ||= $self->{'_plugins'};

	for my $answer (@$answers) {
		for (keys %$plugins) {
			if ($answer eq $plugins->{$_}{order}) {
				$self->_install($plugins->{$_}, $symlink);
			}
		}
	}
}

sub _install {
	my($self, $plugin, $symlink) = @_;
	# Yes, performance wise this is questionable, if getValue() was
	# cached.... who cares this is the install. -Brian
	if ($self->exists('plugin', $plugin->{name})) {
		print STDERR "Plugin $plugin->{name} has already been installed\n";
		return;
	}
	return if $self->exists('plugin', $plugin->{name});
	my $hostname = $self->getValue('basedomain');
	my $email = $self->getValue('adminmail');
	my $driver = $self->getValue('db_driver');
	my $prefix_site = $self->getValue('site_install_directory');

	$self->create({
		name            => 'plugin',
		value           => $plugin->{'name'},
		description     => $plugin->{'description'},
	});

	for (@{$plugin->{'htdoc'}}) {
		if ($symlink) {
			symlink "$plugin->{'dir'}/$_", "$prefix_site/htdocs/$_";
		} else {
			copy "$plugin->{'dir'}/$_", "$prefix_site/htdocs/$_";
			chmod(0755, "$prefix_site/htdocs/$_");
		}
	}

	for (@{$plugin->{'image'}}) {
		if ($symlink) {
			symlink "$plugin->{'dir'}/$_", "$prefix_site/htdocs/images/$_";
		} else {
			copy "$plugin->{'dir'}/$_", "$prefix_site/htdocs/images/$_";
			chmod(0755, "$prefix_site/htdocs/images/$_");
		}
	}

	my($sql, @sql, @create);

	if ($plugin->{"${driver}_schema"}) {
		if (my $schema_file = "$plugin->{dir}/" . $plugin->{"${driver}_schema"}) {
			open(CREATE, "< $schema_file");
			while (<CREATE>) {
				chomp;
				next if /^#/;
				next if /^$/;
				next if /^ $/;
				push @create, $_;
			}
			close (CREATE);

			$sql = join '', @create;
			@sql = split /;/, $sql;
		}
	}

	if ($plugin->{"${driver}_dump"}) {
		if (my $dump_file = "$plugin->{dir}/" . $plugin->{"${driver}_dump"}) {
			open(DUMP,"< $dump_file");
			while(<DUMP>) {
				next unless /^INSERT/;
				chomp;
				s/www\.example\.com/$hostname/g;
				s/admin\@example\.com/$email/g;
				push @sql, $_;
			}
			close(DUMP);
		}
	}

	for (@sql) {
		next unless $_;
		unless ($self->sqlDo($_)) {
			print "Failed on :$_:\n";
		}
	}

	if($plugin->{'template'}) {
		for(@{$plugin->{'template'}}) {
			my $template = $self->readTemplateFile("$plugin->{'dir'}/$_");
			$self->{slashdb}->createTemplate($template) if $template;
		}
	}
	if ($plugin->{note}) {
		my $file = "$plugin->{dir}/$plugin->{note}";  
		open(FILE, $file);
		while(<FILE>) {
			print;
		}
	}
}

sub getPluginList {
	my($self, $prefix) = @_;
	$self->{'_install_dir'} = $prefix;
	opendir(PLUGINDIR, "$prefix/plugins");
	my %plugins;
	while (my $dir = readdir(PLUGINDIR)) {
		next if $dir =~ /^\.$/;
		next if $dir =~ /^\.\.$/;
		next if $dir =~ /^CVS$/;
		open(PLUGIN, "< $prefix/plugins/$dir/PLUGIN") or next; 
		$plugins{$dir}->{'dir'} = "$prefix/plugins/$dir";
		#This should be override by the actual name of the plugin
		$plugins{$dir}->{'name'} = $dir;

		my @info;
		{
			local $/;
			@info = split /\015\012?|\012/, <PLUGIN>;
		}

		for (@info) {
			next if /^#/;
			my($key, $val) = split(/=/, $_, 2);
			$key = lc $key;
			if ($key eq 'htdoc') {
				push @{$plugins{$dir}->{$key}}, $val;
			} elsif ($key eq 'template') {
				push @{$plugins{$dir}->{$key}}, $val;
			} elsif ($key eq 'image') {
				push @{$plugins{$dir}->{$key}}, $val;
			} else {
				$plugins{$dir}->{$key} = $val;
			}
		}
	}
	my $x = 0;
	for (sort keys %plugins) {
		$x++;
		$plugins{$_}->{'order'} = $x;
	}

	$self->{'_plugins'} = \%plugins;
	return \%plugins;
}

1;

__END__

=head1 NAME

Slash::Install - Install libraries for slash

=head1 SYNOPSIS

  use Slash::Install;

=head1 DESCRIPTION

This was deciphered from crop circles.

=head1 SEE ALSO

Slash(3).

=cut
