# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# Slash::Plugin is the base class for all Slash plugin database
# classes.  In particular it provides the behavior where the
# class's new() method -- and thus getObject('Slash::PluginName') --
# will return undef if the plugin has not been installed.

package Slash::Plugin;

use strict;
use Slash::Utility::Environment;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;

sub isInstalled {
	my($class) = @_;
	return 1 if $class eq 'Slash::Plugin';
	my($plugin_name) = $class =~ /^Slash::(\w+)$/;
	return 0 if !$plugin_name;
	my $constants = getCurrentStatic();
	return $constants->{plugin}{$plugin_name} || 0;
}

