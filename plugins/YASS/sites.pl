#!/usr/bin/perl -w
use strict;
use Slash;
use Slash::Utility;
use Slash::Display;
use Slash::XML;

sub main {
	my $yass   = getObject('Slash::YASS');
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();


	if($form->{'content_type'} eq 'rss') {
		return xmlDisplay('rss', {
				channel => {
				title   => "$constants->{sitename} links",
				'link'  => "$constants->{absolutedir}/sites.pl?content_type=rss",
			},
			items   => $yass->getActive(15),
		});

#	} elsif ($form->{'content_type'} eq 'ocs') {
#	# Yuck! SQL!  The reason that this is like this is
#	# because I am working on rewriting XML::OCS and
#	# until I am done I am going to leave this like this.
#	# -Brian
#		#require XML::OCS;
#		#my $all = $feed->getActive();
#		my $all = $yass->getActive();
#		my $r = Apache->request;
#		$r->header_out('Cache-Control', 'private');
#		$r->content_type('text/xml');
#		$r->status(200);
#		$r->send_http_header;
#		$r->rflush;
#		my $ocs = XML::OCS->new(
#		    title => xmlencode($constants->{sitename}),
#		    creator => xmlencode($constants->{siteadmin}),
#		    description => 'Known feeds.',
#		    url => xmlencode('{absolutedir}/sites.pl?content_type=ocs'),
#		  );
#
#		my @sites;
#		for (@$all) {
#			my $format = XML::OCS::Format->new(
#				  url => xmlencode($_->{rdf}),
#				  language => xmlencode($_->{language}),
#				  format => xmlencode($_->{format}),
#				  contentType => xmlencode($_->{contenttype}),
#			);
#			my $site = XML::OCS::Channel->new(
#				title => xmlencode($_->{title}),
#				url => xmlencode($_->{url}),
#				description => xmlencode($_->{introtext}),
#				formats => [$format],
#			);
#			push @sites, $site;
#		}
#		$ocs->channels(\@sites);
#		$r->print($ocs->output);
#		$r->status(200);
	} else {

		header("$constants->{sitename} Sites") or return;

		slashDisplay('index', {
			new_sites => $yass->getActive(15),
			all_sites => $form->{all} ? $yass->getActive('',1) : $yass->getActive(),
		});

		footer();
	}
}
createEnvironment();
main();
