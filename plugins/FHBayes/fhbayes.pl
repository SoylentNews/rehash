#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# Once a day, process recent firehose activity and train an
# Algorithm::NaiveBayes object on what constitutes binspam.

use strict;
use vars qw( %task $me $task_exit_flag );
use Algorithm::NaiveBayes;
use File::Path;
use Slash::DB;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = "51 5 * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $hose_reader = getObject('Slash::FireHose', { db_type => 'reader' });
	my $fhb_reader = getObject('Slash::FHBayes', { db_type => 'reader' });
	my $source_labels_hr = $fhb_reader->getSourceLabels( $fhb_reader->getSourceList() );

	slashdLog('adding ' . scalar(keys %$source_labels_hr) . ' instances');
	my $nb = Algorithm::NaiveBayes->new();
	for my $id (keys %$source_labels_hr) {
		my $fh = $hose_reader->getFireHose($id);
		my %attr = ( );
		map { $attr{$_} ||= 0; $attr{$_}++ } split_bayes($fh->{title});
		map { $attr{$_} ||= 0; $attr{$_}++ } split_bayes($fh->{introtext});
		map { $attr{$_} ||= 0; $attr{$_}++ } split_bayes($fh->{bodytext});
		my $label = $source_labels_hr->{$id} ? ['b'] : [];
		$nb->add_instance(attributes => \%attr, label => $label);
	}

	slashdLog('training');
	$nb->train();

	slashdLog('saving');
	my $dir = catdir($constants->{datadir}, 'spam_analysis');
	File::Path::mkpath($dir, 0, 0755);
	my $file = catfile($dir, 'binspam_naivebayes');
	$nb->save_state($file);

	return join(' ',
		'saved analysis of',
		scalar(keys %$source_labels_hr),
		'instances:',
		(-s $file),
		'bytes');
};

1;

