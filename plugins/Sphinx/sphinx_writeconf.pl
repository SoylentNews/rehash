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

#
# Sphinx configuration
# --------------------
#
# The place to start reading if you haven't already is
# <http://sphinxsearch.com/docs/current.html>.
#
# This configuration file currently (2009-01-06) describes a Sphinx
# setup for sd-db-4 in which there are 3 indexes and a distributed
# searchd.  The indexes are "main", "delta1" and "delta2".  The "main"
# index, when run, indexes the entire firehose;  "delta1" indexes
# everything since the "main" index was last run, and "delta2"
# everything since "delta1".  The reason for using two deltas is that
# by decreasing the amount of new data to index, the index time is
# made smaller (under 1 second), which allows for frequent reindexing
# (on the order of every 10 seconds;  I actually hope and expect we
# can reindex every 5 seconds on the live site).
#
# To be clear, we are doing incremental indexing -- but not by document
# creation time or creation ID, rather by document update time.  Since
# the same document can only be created once, but can be updated
# repeatedly, this is somewhat different than described in the docs
# at <http://sphinxsearch.com/docs/current.html#live-updates>.  Sphinx
# is flexible enough to support this, but we had to figure it out on
# our own since nobody else seems to have written about doing this yet.
#
# Sphinx allows an index to have multiple data sources;  for simplicity,
# I'm giving each index one data source (e.g. idx_firehose_main uses
# src_firehose_main) with the exception that idx_firehose_dist not
# only uses src_firehose_delta2 but also returns distributed answers
# by consulting the other two indexes.
#
# The table sphinx_counter coordinates which indexes have run and
# stores the data each index run requires.  Sphinx provides config
# options to issue an SQL query before and after each index run --
# but as far as I can tell, only one query, so the sql_query_pre and
# sql_query_post_index have to be a little clever to ensure data in
# the table is always valid (even if an index run exits unexpectedly
# at any point).
#
# The src-completion key
# ----------------------
#
# The main trick with sphinx_counter is that the column pair
# (src,completion) is UNIQUE, so a REPLACE INTO will atomically delete
# and rewrite a row.  Its src column segregates the different indexes'
# data (src=0 is idx_firehose_main, src=1 is idx_firehose_delta1, and
# if we decide to index data other than firehose, each of those indexes
# can have a src value of its own too).  The completion column indicates
# completion order, with lower numbers for the most recent runs.  The
# two special completion values are completion=0, which indicates a
# run in progress (or at least a run which was started and has not
# yet finished) and completion=1 which is the most recently completed
# index run.  Multiple rows are stored partly because a log is nice to
# have and partly because a one-row-per-index solution is probably
# doable but arguably not as elegant.
#
# Thus the query to indicate a run is beginning (sql_query_pre) is
#
#	REPLACE INTO sphinx_counter
#		(src, completion, last_seen, started, elapsed)
#		SELECT $i, 0, MAX(last_update), NOW(), NULL
#			FROM firehose
#
# which creates (or, if the previous attempt failed, rewrites) the
# completion=0 row for index $i to indicate an index is ongoing.  By
# storing the max last_update value from the firehose just before the
# actual indexing starts, a starting value for the _next_ delta index
# is available which guarantees that all changes not included in index
# $i will be included in the next delta.  We'll see that referenced in
# the WHERE clause of the deltas' sql_query below.
#
# On index completion, the query to indicate the end of the run
# (sql_query_post_index) updates the src=$i, completion=0 row, setting
# completion to 1, and (for informational purposes) storing the elapsed
# time in the elapsed column.  We can't delete the older columns
# because we only have one query to run at this time, so instead we
# increment all the older columns' completion values, bumping the old
# "1" last-completed row out of the way to make room for the "0" that
# becomes the new "1", and bumping everything above it higher as well.
#
# To make things complicated, the column pair (src,completion) has
# to be declared UNIQUE to make the REPLACE INTO work.  But if a delta
# has 100K rows logged whose completion value need incrementing, this
# can be slow.  So completion is declared as possibly NULL -- any
# number of NULLs are allowed in a UNIQUE key.  Completion values
# above a certain number are simply made NULL, and already-NULL
# completions are not updated, so the UPDATE runs very quickly even
# if the table gets very large.
#
# Depending on how useful old logs would be, we will probably want a
# task that goes through and DELETEs old rows WHERE completion IS NULL.
#
# The UPDATE is performed in order "completion DESC" because otherwise
# collisions will result.
#
# Again, the point of this is to allow delta $i to have a WHERE clause
# in its sql_query, sql_query_killlist, and sql_attr_multi reading:
#
#	AND firehose.last_update >=
#		(SELECT MIN(last_seen) FROM sphinx_counter
#		WHERE src=${i-1} AND completion <= 1)
#
# By picking up both the previously completed index and any index
# that may be in progress, this guarantees that each delta will index
# only as much of the firehose as necessary, and no less than sufficient
# -- and that it will also have accurate knowledge of which of its
# documents supercede its previous indexes -- regardless of whether
# any other indexing attempts have failed, and regardless of in which
# order the various indexing actions are begun or completed.
#
# The above query will not behave as expected if the previous index
# has never even been started once.  It does technically work if the
# previous index is currently in progress for its first run ever, but
# will be inefficient in that case.  For best results, when first
# starting up this behavior, run main once to completion, then each
# delta sequentially.  After that, running any indexes at any time,
# even overlapping, will produce valid (though not necessarily maximally
# efficient) results.
#
# The sql_query
# -------------
#
# The sql_query configuration option looks much the same in the main
# and the deltas.  The main (ha) difference is that main indexes all
# globjs, so it gets that list by checking MIN() and MAX() and then
# iterating through that range in chunks, while the deltas want
# precisely those globjs which have been updated since the parent's
# last run, so they get their list by checking firehose.last_update.
#
# The config option looks intimidating because, while most of each
# data source's config is inherited from the previous source, the
# sql_query can't be "edited" from one to the next so the whole thing
# appears in slightly different form three times.  But it's really
# not that hard to understand.  And despite all its LEFT JOINs,
# because all the joins are on primary keys, it runs lightning-fast.
#
# The structure of the sql_query's is:
#
#	SELECT (detail parts here)
#
# The sql_attr_multi is used to obtain firehose_topics_rendered.
#
# Killlists
# ---------
#
# short section, but it should be here because kill lists are confusing
#
# Distributed search
# ------------------
#
# short section, but it should be here because distributed search is confusing
#
# a short note that we could distribute this out to multiple machines --
# comment on how (separate slave on each physical machine) and note that
# I don't know how to rotate/SIGHUP on multiple machines with shared disk
# but apparently there is a way

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
					completion=IF(completion<100,completion+1,NULL)		\
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
		globjs.globjid AS globjidattr,							\
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
		FLOOR(neediness + 1000000) AS neediness,					\
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
	sql_attr_uint		= globjidattr
	sql_attr_uint		= gtid
	sql_attr_uint		= type
	sql_attr_uint		= popularity
	sql_attr_uint		= editorpop
	sql_attr_uint		= neediness
	sql_attr_uint		= public
	sql_attr_uint		= accepted
	sql_attr_uint		= rejected
	sql_attr_uint		= attention_needed
	sql_attr_uint		= is_spam
	sql_attr_uint		= category
	sql_attr_uint		= offmainpage
	sql_attr_uint		= primaryskid
	sql_attr_uint		= uid

	sql_attr_multi		= uint signoff from ranged-query				\
		;										\
		SELECT firehose.globjid, signoff.uid						\
			FROM firehose, globjs, signoff						\
			WHERE firehose.globjid BETWEEN $start AND $end				\
			AND firehose.globjid=globjs.globjid					\
			AND gtid=1								\
			AND globjs.target_id=signoff.stoid					\
		;										\
		SELECT MIN(firehose.globjid), MAX(firehose.globjid) FROM firehose, globjs	\
			WHERE firehose.globjid=globjs.globjid AND gtid = 1

	sql_attr_multi		= uint tid from ranged-query					\
		;										\
		SELECT firehose.globjid, firehose_topics_rendered.tid				\
			FROM firehose, globjs, firehose_topics_rendered				\
			WHERE firehose.globjid BETWEEN $start AND $end				\
			AND firehose.globjid=globjs.globjid					\
			AND gtid IN (1,3,4,5,7,11)						\
			AND firehose.id=firehose_topics_rendered.id				\
		;										\
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
					completion=IF(completion<100,completion+1,NULL)		\
					WHERE src=1 AND completion IS NOT NULL			\
					ORDER BY completion DESC
	sql_query_range		=
	sql_query		= SELECT							\
		globjs.globjid,									\
		UNIX_TIMESTAMP(IF(firehose_ogaspt.globjid IS NOT NULL,				\
			firehose_ogaspt.pubtime,						\
			firehose.createtime))  AS createtime_ut,				\
		UNIX_TIMESTAMP(firehose.last_update) AS last_update_ut,				\
		globjs.globjid AS globjidattr,							\
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
		FLOOR(neediness + 1000000) AS neediness,					\
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

	sql_attr_multi		= uint signoff from query					\
		;										\
		SELECT firehose.globjid, signoff.uid						\
			FROM firehose, globjs, signoff						\
			WHERE firehose.globjid=globjs.globjid					\
			AND gtid=1								\
			AND globjs.target_id=signoff.stoid					\
			AND firehose.last_update >=						\
				(SELECT MIN(last_seen) FROM sphinx_counter			\
				WHERE src=0 AND completion <= 1)

	sql_attr_multi		= uint tid from query						\
		;										\
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
					completion=IF(completion<100,completion+1,NULL)		\
					WHERE src=2 AND completion IS NOT NULL			\
					ORDER BY completion DESC
	sql_query_range		=
	sql_query		= SELECT							\
		globjs.globjid,									\
		UNIX_TIMESTAMP(IF(firehose_ogaspt.globjid IS NOT NULL,				\
			firehose_ogaspt.pubtime,						\
			firehose.createtime))  AS createtime_ut,				\
		UNIX_TIMESTAMP(firehose.last_update) AS last_update_ut,				\
		globjs.globjid AS globjidattr,							\
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
		FLOOR(neediness + 1000000) AS neediness,					\
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

	sql_attr_multi		= uint signoff from query					\
		;										\
		SELECT firehose.globjid, signoff.uid						\
			FROM firehose, globjs, signoff						\
			WHERE firehose.globjid=globjs.globjid					\
			AND gtid=1								\
			AND globjs.target_id=signoff.stoid					\
			AND firehose.last_update >=						\
				(SELECT MIN(last_seen) FROM sphinx_counter			\
				WHERE src=1 AND completion <= 1)

	sql_attr_multi		= uint tid from query						\
		;										\
		SELECT firehose.globjid, firehose_topics_rendered.tid				\
			FROM firehose, globjs, firehose_topics_rendered				\
			WHERE firehose.globjid=globjs.globjid					\
			AND gtid IN (1,3,4,5,7,11)						\
			AND firehose.id=firehose_topics_rendered.id				\
			AND firehose.last_update >=						\
				(SELECT MIN(last_seen) FROM sphinx_counter			\
				WHERE src=1 AND completion <= 1)
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

# "Kill-list for a given index suppresses results from other indexes,
# depending on index order in the query.  ... We now reindex delta
# and then search through both these indexes in proper (least to
# most recent) order"
# http://sphinxsearch.com/docs/current.html#conf-sql-query-killlist

index idx_firehose_dist
{
	type                    = distributed
	agent                   = localhost:3312:idx_firehose_main
	agent                   = localhost:3312:idx_firehose_delta1
	local                   = idx_firehose_delta2
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
	max_matches		= 10000
}
EOF

1;

