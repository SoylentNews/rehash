#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# TODO: should be a way in here to adjust memlimit, stopwords, etc.,
# using vars.

use strict;

use File::Spec::Functions;
use Slash;
use Slash::Constants ':slashd';

use vars qw(
	%task	$me	$task_exit_flag
	$filedata
);

$task{$me}{timespec} = '1 1 1 1 *'; # this really doesn't need to run periodically...
$task{$me}{on_startup} = 1;         # ...once every slashd startup is fine
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $sphinxdb = getObject('Slash::Sphinx', { db_type => 'sphinx' });
	return 'sphinx apparently not installed, exiting' unless $sphinxdb;
	my $num = $sphinxdb->getNum();

	# If/when multiple sphinx DBs are supported, iterate through them all.
	return "multiple sphinx DBs not yet supported: '$num'" unless $num && $num+0 == 1;

	my $vu = DBIx::Password::getVirtualUser( $sphinxdb->{virtual_user} );
	return 'no sphinx vu!?' unless $vu;
	my $hostname = $constants->{sphinx_01_hostname} || $vu->{host} || '';
	return 'no hostname defined' unless $hostname;
	my $sphinx_port = $constants->{sphinx_01_port} || 3312;
	my $sql_port = $vu->{port} || 3306;
	my $max_children = $constants->{sphinx_01_max_children} || 100;
	my $max_iops =     $constants->{sphinx_01_max_iops}     || 40;
	my $max_matches =  $constants->{sphinx_01_max_matches}  || 10000;
	my $mem_limit =    $constants->{sphinx_01_mem_limit}    || '512M';
	my $vardir =       $constants->{sphinx_01_vardir}       || '/srv/sphinx/var';

	my $stopwordsfile = catfile($vardir, 'data', 'stopwords.txt');
	my @stopwords = $sphinxdb->getSphinxStopwords();
	if (open(my $fh, ">$stopwordsfile")) {
		print $fh join("\n", @stopwords) . "\n";
		close $fh;
	} else {
		# log err
	}

	my $writedir = catdir($constants->{datadir}, 'misc');
	my $writefile = catfile($writedir, "sphinx$num.conf");

	$filedata =~ s/ __SPHINX_${num}_HOSTNAME__     /$hostname/gx;
	$filedata =~ s/ __SPHINX_${num}_PORT__         /$sphinx_port/gx;
	$filedata =~ s/ __SPHINX_${num}_SQL_USER__     /$vu->{username}/gx;
	$filedata =~ s/ __SPHINX_${num}_SQL_PASS__     /$vu->{password}/gx;
	$filedata =~ s/ __SPHINX_${num}_SQL_DB__       /$vu->{database}/gx;
	$filedata =~ s/ __SPHINX_${num}_SQL_HOST__     /$vu->{host}/gx;
	$filedata =~ s/ __SPHINX_${num}_SQL_PORT__     /$sql_port/gx;
	$filedata =~ s/ __SPHINX_${num}_SQL_SOCK__     //gx; # no way to get this info at the moment, which is ok
	$filedata =~ s/ __SPHINX_${num}_MAX_CHILDREN__ /$max_children/gx;
	$filedata =~ s/ __SPHINX_${num}_MAX_IOPS__     /$max_iops/gx;
	$filedata =~ s/ __SPHINX_${num}_MAX_MATCHES__  /$max_matches/gx;
	$filedata =~ s/ __SPHINX_${num}_MEM_LIMIT__    /$mem_limit/gx;
	$filedata =~ s/ __SPHINX_${num}_VARDIR__       /$vardir/gx;

	# XXX considering indexer is running frequently and reading this
	# file, should write it to a new file and mv it into place.
	if (open(my $fh, ">$writefile")) {
		print $fh $filedata;
		close $fh;
	} else {
		return "could not write $writefile, $!";
	}

	return 'wrote ' . (-s $writefile) . " bytes to $writefile";
};

$filedata = <<'EOF';
#
# Sphinx conf file for testing firehose indexing and searching.
# To be run on __SPHINX_01_HOSTNAME__.
#

source src_firehose_main
{
	type			= mysql

	sql_user		= __SPHINX_01_SQL_USER__
	sql_pass		= __SPHINX_01_SQL_PASS__
	sql_db			= __SPHINX_01_SQL_DB__
	sql_host		= __SPHINX_01_SQL_HOST__
	sql_port		= __SPHINX_01_SQL_PORT__
	sql_sock		= __SPHINX_01_SQL_SOCK__

	sql_query_pre		= SET SESSION query_cache_type=OFF
	sql_query_pre		= REPLACE INTO sphinx_counter					\
					(src, completion, last_seen, started, elapsed)		\
					SELECT 0, 0, MAX(last_update), NOW(), NULL FROM firehose
	sql_query_post_index	= UPDATE IGNORE sphinx_counter					\
					SET elapsed=IF(elapsed IS NULL,				\
						UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(started),	\
						elapsed),					\
					completion=IF(completion<1000,completion+1,NULL)	\
					WHERE src=0 AND completion IS NOT NULL			\
					ORDER BY completion DESC
	sql_query_range		= SELECT MIN(globjid), MAX(globjid) FROM firehose
	sql_range_step		= 10000
	sql_query		= SELECT							\
		globjs.globjid,									\
		UNIX_TIMESTAMP(IF(firehose_ogaspt.globjid IS NOT NULL,				\
			firehose_ogaspt.pubtime,						\
			firehose.createtime)) AS createtime_ut,					\
		UNIX_TIMESTAMP(firehose.last_update) AS last_update_ut,				\
		IF(     gtid= 1, CONCAT(story_text.title,					\
				' ', firehose.toptags,						\
				' ', story_text.introtext,					\
				' ', story_text.bodytext),					\
		  IF(   gtid= 3, CONCAT(submissions.subj,					\
				' ', firehose.toptags,						\
				' ', submissions.story),					\
		  IF(   gtid= 4, CONCAT(journals.description,					\
				' ', firehose.toptags,						\
				' ', journals_text.article),					\
		  IF(   gtid= 5, IF(comments.subject_orig='yes',				\
				CONCAT(comments.subject,					\
				' ', comment_text.comment),					\
				comment_text.comment),						\
		  IF(   gtid= 7, CONCAT(discussions.title,					\
				' ', firehose.toptags),						\
		  IF(   gtid=11, CONCAT(projects.unixname,					\
				' ', projects.textname,						\
				' ', firehose.toptags,						\
				' ', projects.description),					\
			CONCAT(firehose_text.title,						\
				' ', firehose.toptags,						\
				' ', firehose_text.introtext,					\
				' ', firehose_text.bodytext)					\
		)))))) AS index_text,								\
		gtid,										\
		IF(	firehose.type='story',       1,						\
		  IF(	firehose.type='submission',  3,						\
		  IF(	firehose.type='journal',     4,						\
		  IF(	firehose.type='comment',     5,						\
		  IF(	firehose.type='discussion',  7,						\
		  IF(	firehose.type='project',    11,						\
		  IF(	firehose.type='bookmark',   12,						\
		  IF(	firehose.type='feed',       13,						\
		  IF(	firehose.type='vendor',     14,						\
		  IF(	firehose.type='misc',       15,						\
			                          9999						\
		)))))))))) AS type,								\
		FLOOR(popularity + 1000000) AS popularity,					\
		FLOOR(editorpop + 1000000) AS editorpop,					\
		IF(public='yes',1,0) AS public,							\
		IF(accepted='yes',1,0) AS accepted,						\
		IF(rejected='yes',1,0) AS rejected,						\
		IF(attention_needed='yes',1,0) AS attention_needed,				\
		IF(is_spam='yes',1,0) AS is_spam,						\
		IF(	category='',        0,							\
		  IF(	category='Back',    1,							\
		  IF(	category='Hold',    2,							\
		  IF(	category='Quik',    3,							\
			                 9999							\
		)))) AS category,								\
		IF(offmainpage='yes',1,0) AS offmainpage,					\
		firehose.primaryskid,								\
		firehose.uid									\
	FROM											\
		firehose									\
			LEFT JOIN firehose_ogaspt USING (globjid),				\
		firehose_text,									\
		globjs										\
			LEFT JOIN stories       ON (gtid= 1 AND target_id=stories.stoid)	\
			LEFT JOIN story_text    ON (gtid= 1 AND target_id=story_text.stoid)	\
			LEFT JOIN submissions   ON (gtid= 3 AND target_id=submissions.subid)	\
			LEFT JOIN journals      ON (gtid= 4 AND target_id=journals.id)		\
			LEFT JOIN journals_text ON (gtid= 4 AND target_id=journals_text.id)	\
			LEFT JOIN comments      ON (gtid= 5 AND target_id=comments.cid)		\
			LEFT JOIN comment_text  ON (gtid= 5 AND target_id=comment_text.cid)	\
			LEFT JOIN discussions	ON (gtid= 7 AND target_id=discussions.id)	\
			LEFT JOIN projects	ON (gtid=11 AND target_id=projects.id)		\
	WHERE firehose.globjid=globjs.globjid							\
		AND firehose.id=firehose_text.id						\
		AND gtid IN (1,3,4,5,7,11)							\
		AND firehose.globjid BETWEEN $start AND $end

	sql_attr_timestamp	= createtime_ut
	sql_attr_timestamp	= last_update_ut
	sql_attr_uint		= gtid
	sql_attr_uint		= type
	sql_attr_uint		= popularity
	sql_attr_uint		= editorpop
	sql_attr_uint		= public
	sql_attr_uint		= accepted
	sql_attr_uint		= rejected
	sql_attr_uint		= attention_needed
	sql_attr_uint		= is_spam
	sql_attr_uint		= category
	sql_attr_uint		= offmainpage
	sql_attr_uint		= primaryskid
	sql_attr_uint		= uid

	sql_attr_multi		= uint tid from ranged-query			;		\
		SELECT firehose.globjid, firehose_topics_rendered.tid				\
			FROM firehose, globjs, firehose_topics_rendered				\
			WHERE firehose.globjid BETWEEN $start AND $end				\
			AND firehose.globjid=globjs.globjid					\
			AND gtid IN (1,3,4,5,7,11)						\
			AND firehose.id=firehose_topics_rendered.id		;		\
		SELECT MIN(firehose.globjid), MAX(firehose.globjid) FROM firehose, globjs	\
			WHERE firehose.globjid=globjs.globjid AND gtid IN (1,3,4,5,7,11)

	sql_ranged_throttle	= 10
}

source src_firehose_delta1 : src_firehose_main
{
	sql_query_pre		= SET SESSION query_cache_type=OFF
	sql_query_pre		= REPLACE INTO sphinx_counter					\
					(src, completion, last_seen, started, elapsed)		\
					SELECT 1, 0, MAX(last_update), NOW(), NULL FROM firehose
	sql_query_killlist	= SELECT DISTINCT globjid FROM firehose				\
					WHERE last_update >= (					\
						SELECT MIN(last_seen) FROM sphinx_counter	\
						WHERE src=0 AND completion <= 1			\
					)
	sql_query_post_index	= UPDATE IGNORE sphinx_counter					\
					SET elapsed=IF(elapsed IS NULL,				\
						UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(started),	\
						elapsed),					\
					completion=IF(completion<1000,completion+1,NULL)	\
					WHERE src=1 AND completion IS NOT NULL			\
					ORDER BY completion DESC
	sql_query_range		=
	sql_query		= SELECT							\
		globjs.globjid,									\
		UNIX_TIMESTAMP(IF(firehose_ogaspt.globjid IS NOT NULL,				\
			firehose_ogaspt.pubtime,						\
			firehose.createtime))  AS createtime_ut,				\
		UNIX_TIMESTAMP(firehose.last_update) AS last_update_ut,				\
		IF(     gtid= 1, CONCAT(story_text.title,					\
				' ', firehose.toptags,						\
				' ', story_text.introtext,					\
				' ', story_text.bodytext),					\
		  IF(   gtid= 3, CONCAT(submissions.subj,					\
				' ', firehose.toptags,						\
				' ', submissions.story),					\
		  IF(   gtid= 4, CONCAT(journals.description,					\
				' ', firehose.toptags,						\
				' ', journals_text.article),					\
		  IF(   gtid= 5, IF(comments.subject_orig='yes',				\
				CONCAT(comments.subject,					\
				' ', comment_text.comment),					\
				comment_text.comment),						\
		  IF(   gtid= 7, CONCAT(discussions.title,					\
				' ', firehose.toptags),						\
		  IF(   gtid=11, CONCAT(projects.unixname,					\
				' ', projects.textname,						\
				' ', firehose.toptags,						\
				' ', projects.description),					\
			CONCAT(firehose_text.title,						\
				' ', firehose.toptags,						\
				' ', firehose_text.introtext,					\
				' ', firehose_text.bodytext)					\
		)))))) AS index_text,								\
		gtid,										\
		IF(	firehose.type='story',       1,						\
		  IF(	firehose.type='submission',  3,						\
		  IF(	firehose.type='journal',     4,						\
		  IF(	firehose.type='comment',     5,						\
		  IF(	firehose.type='discussion',  7,						\
		  IF(	firehose.type='project',    11,						\
		  IF(	firehose.type='bookmark',   12,						\
		  IF(	firehose.type='feed',       13,						\
		  IF(	firehose.type='vendor',     14,						\
		  IF(	firehose.type='misc',       15,						\
			                          9999						\
		)))))))))) AS type,								\
		FLOOR(popularity + 1000000) AS popularity,					\
		FLOOR(editorpop + 1000000) AS editorpop,					\
		IF(public='yes',1,0) AS public,							\
		IF(accepted='yes',1,0) AS accepted,						\
		IF(rejected='yes',1,0) AS rejected,						\
		IF(attention_needed='yes',1,0) AS attention_needed,				\
		IF(is_spam='yes',1,0) AS is_spam,						\
		IF(	category='',        0,							\
		  IF(	category='Back',    1,							\
		  IF(	category='Hold',    2,							\
		  IF(	category='Quik',    3,							\
			                 9999							\
		)))) AS category,								\
		IF(offmainpage='yes',1,0) AS offmainpage,					\
		firehose.primaryskid,								\
		firehose.uid									\
	FROM											\
		firehose									\
			LEFT JOIN firehose_ogaspt USING (globjid),				\
		firehose_text,									\
		globjs										\
			LEFT JOIN stories       ON (gtid= 1 AND target_id=stories.stoid)	\
			LEFT JOIN story_text    ON (gtid= 1 AND target_id=story_text.stoid)	\
			LEFT JOIN submissions   ON (gtid= 3 AND target_id=submissions.subid)	\
			LEFT JOIN journals      ON (gtid= 4 AND target_id=journals.id)		\
			LEFT JOIN journals_text ON (gtid= 4 AND target_id=journals_text.id)	\
			LEFT JOIN comments      ON (gtid= 5 AND target_id=comments.cid)		\
			LEFT JOIN comment_text  ON (gtid= 5 AND target_id=comment_text.cid)	\
			LEFT JOIN discussions	ON (gtid= 7 AND target_id=discussions.id)	\
			LEFT JOIN projects	ON (gtid=11 AND target_id=projects.id)		\
	WHERE firehose.globjid=globjs.globjid							\
		AND firehose.id=firehose_text.id						\
		AND gtid IN (1,3,4,5,7,11)							\
		AND firehose.last_update >=							\
			(SELECT MIN(last_seen) FROM sphinx_counter				\
			WHERE src=0 AND completion <= 1)

	sql_attr_multi		= uint tid from query				;		\
		SELECT firehose.globjid, firehose_topics_rendered.tid				\
			FROM firehose, globjs, firehose_topics_rendered				\
			WHERE firehose.globjid=globjs.globjid					\
			AND gtid IN (1,3,4,5,7,11)						\
			AND firehose.id=firehose_topics_rendered.id				\
			AND firehose.last_update >=						\
				(SELECT MIN(last_seen) FROM sphinx_counter			\
				WHERE src=0 AND completion <= 1)

}

source src_firehose_delta2 : src_firehose_main
{
	sql_query_pre		= SET SESSION query_cache_type=OFF
	sql_query_pre		= REPLACE INTO sphinx_counter					\
					(src, completion, last_seen, started, elapsed)		\
					SELECT 2, 0, MAX(last_update), NOW(), NULL FROM firehose
	sql_query_killlist	= SELECT DISTINCT globjid FROM firehose				\
					WHERE last_update >= (					\
						SELECT MIN(last_seen) FROM sphinx_counter	\
						WHERE src=1 AND completion <= 1			\
					)
	sql_query_post_index	= UPDATE IGNORE sphinx_counter					\
					SET elapsed=IF(elapsed IS NULL,				\
						UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(started),	\
						elapsed),					\
					completion=IF(completion<1000,completion+1,NULL)	\
					WHERE src=2 AND completion IS NOT NULL			\
					ORDER BY completion DESC
	sql_query_range		=
	sql_query		= SELECT							\
		globjs.globjid,									\
		UNIX_TIMESTAMP(IF(firehose_ogaspt.globjid IS NOT NULL,				\
			firehose_ogaspt.pubtime,						\
			firehose.createtime))  AS createtime_ut,				\
		UNIX_TIMESTAMP(firehose.last_update) AS last_update_ut,				\
		IF(     gtid= 1, CONCAT(story_text.title,					\
				' ', firehose.toptags,						\
				' ', story_text.introtext,					\
				' ', story_text.bodytext),					\
		  IF(   gtid= 3, CONCAT(submissions.subj,					\
				' ', firehose.toptags,						\
				' ', submissions.story),					\
		  IF(   gtid= 4, CONCAT(journals.description,					\
				' ', firehose.toptags,						\
				' ', journals_text.article),					\
		  IF(   gtid= 5, IF(comments.subject_orig='yes',				\
				CONCAT(comments.subject,					\
				' ', comment_text.comment),					\
				comment_text.comment),						\
		  IF(   gtid= 7, CONCAT(discussions.title,					\
				' ', firehose.toptags),						\
		  IF(   gtid=11, CONCAT(projects.unixname,					\
				' ', projects.textname,						\
				' ', firehose.toptags,						\
				' ', projects.description),					\
			CONCAT(firehose_text.title,						\
				' ', firehose.toptags,						\
				' ', firehose_text.introtext,					\
				' ', firehose_text.bodytext)					\
		)))))) AS index_text,								\
		gtid,										\
		IF(	firehose.type='story',       1,						\
		  IF(	firehose.type='submission',  3,						\
		  IF(	firehose.type='journal',     4,						\
		  IF(	firehose.type='comment',     5,						\
		  IF(	firehose.type='discussion',  7,						\
		  IF(	firehose.type='project',    11,						\
		  IF(	firehose.type='bookmark',   12,						\
		  IF(	firehose.type='feed',       13,						\
		  IF(	firehose.type='vendor',     14,						\
		  IF(	firehose.type='misc',       15,						\
			                          9999						\
		)))))))))) AS type,								\
		FLOOR(popularity + 1000000) AS popularity,					\
		FLOOR(editorpop + 1000000) AS editorpop,					\
		IF(public='yes',1,0) AS public,							\
		IF(accepted='yes',1,0) AS accepted,						\
		IF(rejected='yes',1,0) AS rejected,						\
		IF(attention_needed='yes',1,0) AS attention_needed,				\
		IF(is_spam='yes',1,0) AS is_spam,						\
		IF(	category='',        0,							\
		  IF(	category='Back',    1,							\
		  IF(	category='Hold',    2,							\
		  IF(	category='Quik',    3,							\
			                 9999							\
		)))) AS category,								\
		IF(offmainpage='yes',1,0) AS offmainpage,					\
		firehose.primaryskid,								\
		firehose.uid									\
	FROM											\
		firehose									\
			LEFT JOIN firehose_ogaspt USING (globjid),				\
		firehose_text,									\
		globjs										\
			LEFT JOIN stories       ON (gtid= 1 AND target_id=stories.stoid)	\
			LEFT JOIN story_text    ON (gtid= 1 AND target_id=story_text.stoid)	\
			LEFT JOIN submissions   ON (gtid= 3 AND target_id=submissions.subid)	\
			LEFT JOIN journals      ON (gtid= 4 AND target_id=journals.id)		\
			LEFT JOIN journals_text ON (gtid= 4 AND target_id=journals_text.id)	\
			LEFT JOIN comments      ON (gtid= 5 AND target_id=comments.cid)		\
			LEFT JOIN comment_text  ON (gtid= 5 AND target_id=comment_text.cid)	\
			LEFT JOIN discussions	ON (gtid= 7 AND target_id=discussions.id)	\
			LEFT JOIN projects	ON (gtid=11 AND target_id=projects.id)		\
	WHERE firehose.globjid=globjs.globjid							\
		AND firehose.id=firehose_text.id						\
		AND gtid IN (1,3,4,5,7,11)							\
		AND firehose.last_update >=							\
			(SELECT MIN(last_seen) FROM sphinx_counter				\
			WHERE src=1 AND completion <= 1)

	sql_attr_multi		= uint tid from query				;		\
		SELECT firehose.globjid, firehose_topics_rendered.tid				\
			FROM firehose, globjs, firehose_topics_rendered				\
			WHERE firehose.globjid=globjs.globjid					\
			AND gtid IN (1,3,4,5,7,11)						\
			AND firehose.id=firehose_topics_rendered.id				\
			AND firehose.last_update >=						\
				(SELECT MIN(last_seen) FROM sphinx_counter			\
				WHERE src=0 AND completion <= 1)
}

index idx_firehose_main
{
	source			= src_firehose_main
	path			= __SPHINX_01_VARDIR__/data/firehose_main
	morphology		= none
	stopwords		= __SPHINX_01_VARDIR__/data/stopwords.txt
	min_word_len		= 2
	charset_type		= sbcs
	html_strip		= 1
	html_index_attrs	= a=href
	html_remove_elements	= style, script
}

index idx_firehose_delta1 : idx_firehose_main
{
	source			= src_firehose_delta1
	path			= __SPHINX_01_VARDIR__/data/firehose_delta1
}

index idx_firehose_delta2 : idx_firehose_main
{
	source			= src_firehose_delta2
	path			= __SPHINX_01_VARDIR__/data/firehose_delta2
}

index idx_firehose_dist
{
	type                    = distributed
	local                   = idx_firehose_delta2
	agent                   = localhost:3312:idx_firehose_delta1
	agent                   = localhost:3312:idx_firehose_main
}

indexer
{
	mem_limit		= 512M
	max_iops		= 40
	max_iosize		= 1048576
}

searchd
{
	listen			= 3312
	log			= __SPHINX_01_VARDIR__/log/searchd.log
	query_log		= __SPHINX_01_VARDIR__/log/query.log
	max_children		= 100
	pid_file		= __SPHINX_01_VARDIR__/log/searchd.pid
	max_matches		= 100000
}
EOF

1;

