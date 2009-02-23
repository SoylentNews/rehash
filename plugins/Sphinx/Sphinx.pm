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

sub getSphinxStats {
	my($self) = @_;

	# requires SUPER privs, so don't use this if we can help it
	# reports "total: 25, total found: 25, time: 126, words: 2"
# 	my $sql = 'SHOW ENGINE SPHINX STATUS';

	# returns variables named: sphinx_total, sphinx_total_found,
	# sphinx_time, sphinx_word_count, sphinx_words
	my $sql = 'SHOW STATUS LIKE "sphinx_%"';
	my $sth = $self->{_dbh}->prepare($sql);
	if (!$sth->execute) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}

	my %stats;

	if ($sql =~ /SHOW ENGINE/) {
		my @data = $sth->fetchrow;
		$sth->finish;

		return undef unless $data[2] && $data[2] =~ /:/;

		while ($data[2] =~ /(\w[\w\s]+): (\d+)/g) {
			$stats{$1} = $2;
		}
	} else {
		while (my $data = $sth->fetchrow_arrayref) {
			next if $data->[1] =~ /\D/;
			(my $name = $data->[0]) =~ s/^sphinx_//;
			$name =~ s/_/ /g;
			my $num = $data->[1] & 2**31-1;
			$stats{$name} = $num;
		}
	}

	return \%stats;
}

sub getSphinxStopwords {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $sw = $constants->{sphinx_stopwords} || '';
	my @sw = split / /, $sw;
	return @sw;
}

