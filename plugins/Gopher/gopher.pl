#!/usr/bin/perl -w
package Slash::Gopher;

use strict;
use vars qw(@ISA);

use Data::Dumper;
use Slash;
use Slash::DB;
use Slash::Utility;
use Net::Server::PreFork; # any personality will do

@ISA = qw(Net::Server::PreFork);

sub gopher_info {
	my ($string) = @_;
	# Just makes our life a lot saner to have this wrapper function
	print "i" . $string ."		error.host	1\n"; 
}

sub gopher_link {
	my ($link, $resource) = @_;

	print "1$link 	$resource	dev.soylentnews.org	70	+\n";
}

sub display_main_menu {
	my ($slashdb, $reader, $constants, $skin, $gopherplus) = @_;
	my @stories;

	# Based off code from index.pl
	my $gse_hr = { };
	$gse_hr->{tid} = [ $skin->{nexus} ];
	my $stories = $reader->getStoriesEssentials($gse_hr);

	my @stoids_for_cache =
		map { $_->{stoid} }
		@$stories;
	my $stories_data_cache;

	$stories_data_cache = $reader->getStoriesData(\@stoids_for_cache) if @stoids_for_cache;

	my @rss_stories = ( );

	if ($gopherplus) {
		print "+-2\n";
	}

	# Get each story
	for (@$stories) {
		my ($story, @ref);
		$story = $reader->getStory($_->{sid});
		$story->{introtext} = parseSlashizedLinks($story->{introtext});
		my $asciitext = $story->{introtext};
		($story->{asciitext}, @ref) = html2text($asciitext, 74);

		my $user = $slashdb->getUser($story->{submitter});

		# If we're not using gopher+, just embed information locally
		if ($gopherplus) {
			print "+INFO: "; 
			gopher_link($story->{title}, ('/article/' . $story->{sid}));

			print "+ADMIN:\n";
			print " Admin: Michael Casadevall \<mcasadevall\@soylentnews.org\>\n";
			print " Mod-Date: 20150314005122\n";
			print "+ABSTRACT:\n";

			# go go gadget brain damage :)
			my @lines = split ('\n', $story->{asciitext});
			foreach (@lines) {
				print " $_\n";
			}
		} else {
			gopher_link($story->{title}, ("/article/" . $story->{sid}));
			gopher_info("  Posted by $user->{nickname} at $story->{time}");
			if ($story->{dept} ne '') {
				gopher_info("  From the $story->{dept} dept");
			}
			gopher_info("");
			my @lines = split ('\n', $story->{asciitext});
			foreach (@lines) {
				gopher_info("   " . $_);
			}
		}
	}

}

sub process_request {
	my $slashdb = getCurrentDB();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $client_uses_gopherplus = 0;

	binmode(STDOUT, ":crlf");
	my $self = shift;
	while (<STDIN>) {
		print STDERR "Gopher response: $_";

		# We need to process the client request here. If we have a Gopher+ client, they may request attributes
		my @request = split (/\t/);
		
		# First part is the selector, this *always* exists
		print STDERR "Gopher selector:  $request[0]\n";
		
		# Second part is the Gopher+ attribute, which may or may not exist
		if (exists $request[1]) {
			print STDERR "Gopher Attribute $request[1]\n";
			$client_uses_gopherplus = $request[1];
		}

		# if empty selector, just give them the main menu
		if ($_ eq '\n' || ($client_uses_gopherplus && $request[0] eq '\n')) {
			display_main_menu($slashdb, $reader, $constants, $gSkin, $client_uses_gopherplus);
			print "\n";
			last;
		}

		# Else determine what to load
		my @resource = split('\/', $request[0]);
		if (exists $resource[1] && $resource[1] eq 'article') {
			gopher_info("not implemented yet");
		} else {
			display_main_menu($slashdb, $reader, $constants, $gSkin, $client_uses_gopherplus);
		}

		print "\n";
	        last;
    	}
}

createEnvironment('slash2');

Slash::Gopher->run(port => 70);

