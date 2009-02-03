# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Sphinx;

use strict;
use Slash;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# At the moment, this module exists only to provide the usual
# way of determining whether a plugin is active:  getObject() it
# and see whether undef comes back.
#
# Useful Sphinx-specific methods may be added later, or may not.

sub isInstalled {
	my($class) = @_;
	my $constants = getCurrentStatic();
	return 0 if ! $constants->{sphinx};
	return $class->SUPER::isInstalled();
}

sub getNum {
	my($self) = @_;
	my $vu = $self->{virtual_user};
	my($num) = $vu =~ /^sphinx(\d+)$/;
	return $num;
}

