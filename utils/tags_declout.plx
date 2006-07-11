#!/usr/bin/perl -w

use strict;
use Slash::Test shift;

use vars qw( $tagsdb );

$tagsdb = getObject('Slash::Tags');
my $command_ar = $tagsdb->sqlSelectAllHashrefArray('*', 'tagcommand_adminlog',
	"cmdtype != '^' AND globjid IS NOT NULL");

if (!$command_ar || !@$command_ar) {
	print "no admin commands\n";
	exit 0;
}

my @tagnameid_globjids = ( );
for my $hr (@$command_ar) {
	push @tagnameid_globjids, "(tags.tagnameid=$hr->{tagnameid} AND tags.globjid=$hr->{globjid})";
}

my $tagid_ar = $tagsdb->sqlSelectColArrayref(
	'tags.tagid',
	"tags LEFT JOIN tag_params ON (tags.tagid=tag_params.tagid AND tag_params.name='tag_clout')",
	'('  . join(' OR ', @tagnameid_globjids) . ') AND tag_params.name IS NULL'
);

if (!$tagid_ar || !@$tagid_ar) {
	print "no tags need declouting\n";
	exit 0;
}

for my $tagid (@$tagid_ar) {
	my $rows = $tagsdb->sqlInsert('tag_params', {
		tagid =>	$tagid,
		name =>		'tag_clout',
		value =>	0,
	}, { ignore => 1 });
	if ($rows) {
		print "declouted $tagid\n";
	} else {
		print "FAILED $tagid\n";
	}
}

