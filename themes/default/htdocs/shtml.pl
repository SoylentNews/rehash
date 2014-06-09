#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use utf8;

use File::Spec::Functions;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my($file_abs, $file_type) = getRequestedFileAndType();
#print STDERR scalar(gmtime) . " shtml.pl file_abs='$file_abs' file_type='$file_type'\n";
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
	my $parsed_data = parse($file_text, $file_type);
	if (!$parsed_data) {
		print STDERR scalar(gmtime) . " shtml.pl no parsed_data for '$file_abs'\n";
		emit404();
		return;
	}
	print $parsed_data;
}

sub getRequestedFileAndType {
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $uri = $form->{uri};
	if (!$uri) {
		warn "no uri";
		return '';
	}

	my($file_rel, $type) = undef;
	if ($uri =~ m{^/(\w+/\d\d/\d\d/\d\d/\d+\.shtml)}) {
		# an article .shtml
		$file_rel = $1;
		$type = 'article';
	} elsif ($uri =~ m{^/(faq[^?;]*?\.shtml)}) {
		# a FAQ entry
		$file_rel = $1;
		$type = 'faq';
	} elsif ($uri =~ m{^/(hof|cheesyportal|authors)\.shtml}) {
		$file_rel = $uri;
		$type = 'gen'; # "generated", with a custom HTML comment
	} elsif ($uri =~ m{^/(about|topics|awards|supporters|prettypictures|moderation)\.shtml}) {
		$file_rel = $uri;
		$type = 'misc';
	}
	if ($file_rel && $type) {
		my $basedir = $constants->{basedir};
		my $file_abs = catfile($basedir, $file_rel);
		return($file_abs, $type);
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
	my($text, $file_type) = @_;

	my($title) = $text =~ m{<title>([^<]+)</title>}si;
	$title ||= '';
	$text = replace_header($text, { type => $file_type, title => $title });
	$text = replace_footer($text, { type => $file_type });

	return $text;
}

sub replace_header {
	my($text, $options) = @_;

	my $title = $options->{title} || '';
	my $header_text = header($title, '', { Return => 1, Page => 'index2', "shtmlpl_$options->{type}" => 1 });

	my $new_header;
	my $replace_anchor;
	if ($options->{type} eq 'faq') {
		$new_header = slashDisplay('header-faq',
			{ header_text => $header_text },
			{ Return => 1, Page => 'shtmlpl' });
		$replace_anchor = '<!--#include virtual="/slashhead-gen-full.inc"-->';
	} elsif ($options->{type} eq 'gen') {
		$new_header = slashDisplay('header-misc',
			{ header_text => $header_text },
			{ Return => 1, Page => 'shtmlpl' });
		$replace_anchor = '<!-- begin generated body -->';
	} elsif ($options->{type} eq 'misc') {
		$new_header = slashDisplay('header-misc',
			{ header_text => $header_text },
			{ Return => 1, Page => 'shtmlpl' });
		$replace_anchor = '<!--#include virtual="/slashhead-gen-full.inc"-->';
	} else {
		$new_header = $header_text;
		$replace_anchor = '<!--#include virtual="/slashhead-gen-full.inc"-->';
	}

	$text =~ s{\A.*$replace_anchor}{$new_header}s;
#	my $repl = $text =~ s{\A.*$replace_anchor}{$new_header}s;
#print STDERR scalar(gmtime) . " replace_header type=$options->{type} repl=$repl len=" . length($new_header) . "\n";
	return $text;
}

sub replace_footer {
	my($text, $options) = @_;

	my $footer_text = footer({ Return => 1, Page => 'index2' });

	my $new_footer;
	my $replace_anchor;
	if ($options->{type} eq 'faq') {
		$new_footer = slashDisplay('footer-faq',
			{ footer_text => $footer_text },
			{ Return => 1, Page => 'shtmlpl' });
		$replace_anchor = '<!--#include virtual="/slashfoot.inc"-->';
	} elsif ($options->{type} eq 'gen') {
		$new_footer = slashDisplay('footer-misc',
			{ footer_text => $footer_text },
			{ Return => 1, Page => 'shtmlpl' });
		$replace_anchor = '<!-- end generated body -->';
	} elsif ($options->{type} eq 'misc') {
		$new_footer = slashDisplay('footer-misc',
			{ footer_text => $footer_text },
			{ Return => 1, Page => 'shtmlpl' });
		$replace_anchor = '<!--#include virtual="/slashfoot.inc"-->';
	} else {
		$new_footer = '';
		$replace_anchor = '<!--#include virtual="/slashfoot.inc"-->';
	}

	$text =~ s{$replace_anchor.*\Z}{$new_footer}s;
#	my $repl = $text =~ s{$replace_anchor.*\Z}{$new_footer}s;
#print STDERR scalar(gmtime) . " replace_footer type=$options->{type} repl=$repl len=" . length($new_footer) . "\n";
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

createEnvironment();
main();

1;

