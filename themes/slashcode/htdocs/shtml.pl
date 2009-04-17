#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;

use File::Spec::Functions;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $file_abs = getRequestedFile();
	if (!$file_abs) {
print STDERR scalar(gmtime) . " shtml.pl no file_abs\n";
		emit404();
		return;
	}
	my $file_text = getFileText($file_abs);
	if (!$file_text) {
print STDERR scalar(gmtime) . " shtml.pl no file_text for '$file_abs'\n";
		emit404();
		return;
	}
	my $parsed_data = parse($file_text);
	if (!$parsed_data) {
print STDERR scalar(gmtime) . " shtml.pl no parsed_data for '$file_abs'\n";
		emit404();
		return;
	}
	print $parsed_data;
}

sub getRequestedFile {
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $uri = $form->{uri};
	if (!$uri) {
		warn "no uri";
		return '';
	}

	if ($uri =~ m{^(/\w+/\d\d/\d\d/\d\d/\d+\.shtml)}) {
		# an article .shtml
		my $file_rel = $1;
		my $basedir = $constants->{basedir};
		my $file_abs = catfile($basedir, $file_rel);
		return $file_abs;
	}
	if ($uri =~ m{^(/faq[^?;]*?\.shtml)}) {
		# a FAQ entry
		my $file_rel = $1;
		my $basedir = $constants->{basedir};
		my $file_abs = catfile($basedir, $file_rel);
		return $file_abs;
	}
#	warn "unknown uri '$uri'";
	return '';
}

sub getFileText {
	my($file_abs) = @_;
	return '' if !$file_abs || $file_abs !~ q{^/};
	# memcached here might be a good thing
	return '' if !-s $file_abs || !-r _;
	my $text = '';
	local $/ = undef;
	if (open my $fh, $file_abs) {
		$text = <$fh>;
		close $fh;
	}
	return $text;
}

sub parse {
	my($text) = @_;

	my($title) = $text =~ m{<title>([^<]+)</title>}si;
	$title ||= '';
	$text = replace_header($text, { title => $title });
	$text = replace_footer($text);

	return $text;
}

#sub expand_includes {
#	my($text) = @_;
#	# If we wanted to handle any of the #include's that
#	# Apache's server-parsed module would do for us,
#	# here's how.  But we probably won't need to do this.
#	$text = s{
#		<!--#include\s+virtual="([^"]+)"[^>]+>
#	}{
#		get_include($1)
#	}gx;
#	return $text;
#}

#sub get_include {
#	my($include_file) = @_;
#	my $constants = getCurrentStatic();
#	my $basedir = $constants->{basedir};
#	my $file_abs = catfile($basedir, $include_file);
#	return getFileText($file_abs);
#}

sub replace_header {
	my($text, $options) = @_;
	my $title = $options->{title} || '';
	$text =~ s{\A.*<!--#include\s+virtual="/slashhead-gen-full.inc"-->}
		{ header($title, '', { Return => 1 }) }se;
	return $text;
}

sub replace_footer {
	my($text) = @_;
	$text =~ s{<!--#include\s+virtual="/slashfoot.inc"-->.*\Z}
		{ footer({ Return => 1 }) }se;
	return $text;
}

createEnvironment();
main();

1;

