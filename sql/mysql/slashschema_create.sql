#	MySQL dump 8.10
#
# Host: localhost	  Database: dump
#--------------------------------------------------------
# Server version	3.23.26-beta
#
# $Id$
#

#
# Table structure for table 'abusers'
#

DROP TABLE IF EXISTS abusers;
CREATE TABLE abusers (
	abuser_id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	pagename varchar(20) DEFAULT '' NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	reason varchar(120) DEFAULT '' NOT NULL,
	querystring varchar(200) DEFAULT '' NOT NULL,
	PRIMARY KEY (abuser_id),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY reason (reason),
	KEY ts (ts)
) TYPE = myisam;

DROP TABLE IF EXISTS accesslist; 
CREATE TABLE accesslist ( 
	id mediumint NOT NULL auto_increment, 
	uid mediumint UNSIGNED NOT NULL,
	ipid char(32),
	subnetid char(32),
	formname varchar(20) DEFAULT '' NOT NULL,
	readonly tinyint UNSIGNED DEFAULT 0 NOT NULL, 
	isbanned tinyint UNSIGNED DEFAULT 0 NOT NULL,
	ts datetime default '0000-00-00 00:00:00' NOT NULL, 
	reason varchar(120), 
	PRIMARY KEY id (id), 
	key uid (uid), 
	key ipid (ipid), 
	key subnetid (subnetid), 
	key formname (formname), 
	key ts (ts)
) TYPE = myisam;

DROP TABLE IF EXISTS accesslog; 
CREATE TABLE accesslog (
	id int UNSIGNED NOT NULL auto_increment,
	host_addr char(32)	DEFAULT '' NOT NULL,
	subnetid char(32)	DEFAULT '' NOT NULL,
	op varchar(254),
	dat varchar(254),
	uid mediumint UNSIGNED NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	query_string varchar(50),
	user_agent varchar(50),
	section varchar(30) DEFAULT 'index' NOT NULL,
	INDEX host_addr_part (host_addr(16)),
	INDEX op_part (op(12)),
	INDEX ts (ts),
	PRIMARY KEY (id)
) TYPE = myisam;

#
# Table structure for table 'authors_cache'
#

DROP TABLE IF EXISTS authors_cache;
CREATE TABLE authors_cache (
	uid mediumint UNSIGNED NOT NULL auto_increment,
	nickname varchar(20) NOT NULL,
	fakeemail varchar(75) NOT NULL,
	homepage varchar(100) NOT NULL,
	storycount mediumint NOT NULL,
	bio text NOT NULL,
	author tinyint DEFAULT 0 NOT NULL,
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'backup_blocks'
#

DROP TABLE IF EXISTS backup_blocks;
CREATE TABLE backup_blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	FOREIGN KEY (bid) REFERENCES blocks(bid),
	PRIMARY KEY (bid)
) TYPE = myisam;

#
# Table structure for table 'blocks'
#

DROP TABLE IF EXISTS blocks;
CREATE TABLE blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	seclev mediumint UNSIGNED NOT NULL DEFAULT '0',
	type ENUM("static","color","portald") DEFAULT 'static' NOT NULL,
	description text,
	section varchar(30) NOT NULL,
	ordernum tinyint DEFAULT '0',
	title varchar(128) NOT NULL,
	portal tinyint NOT NULL DEFAULT '0',
	url varchar(128),
	rdf varchar(255),
	retrieve tinyint NOT NULL DEFAULT '0',
	last_update timestamp,
	rss_template varchar(30),
	items smallint NOT NULL DEFAULT '0', 
	FOREIGN KEY (rss_template) REFERENCES templates(name),
	PRIMARY KEY (bid),
	KEY type (type),
	KEY section (section)
) TYPE = myisam;

#
# Table structure for table 'code_param'
#

DROP TABLE IF EXISTS code_param;
CREATE TABLE code_param (
	param_id smallint UNSIGNED NOT NULL auto_increment,
	type varchar(16) NOT NULL,
	code tinyint DEFAULT '0' NOT NULL,
	name varchar(32) NOT NULL,
	UNIQUE code_key (type,code),
	PRIMARY KEY (param_id)
) TYPE = myisam;

#
# Table structure for table 'commentmodes'
#

DROP TABLE IF EXISTS commentmodes;
CREATE TABLE commentmodes (
	mode varchar(16) DEFAULT '' NOT NULL,
	name varchar(32),
	description varchar(64),
	PRIMARY KEY (mode)
) TYPE = myisam;

#
# Table structure for table 'comments'
#

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
	sid mediumint UNSIGNED NOT NULL,
	cid mediumint UNSIGNED NOT NULL auto_increment,
	pid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	date datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	subject varchar(50) NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	points tinyint DEFAULT '0' NOT NULL,
	lastmod mediumint UNSIGNED DEFAULT '0' NOT NULL,
	reason tinyint UNSIGNED DEFAULT '0' NOT NULL,
	signature char(32) DEFAULT '' NOT NULL,
	PRIMARY KEY (cid),
	KEY display (sid,points,uid),
	KEY byname (uid,points),
	KEY ipid (ipid),
	INDEX (uid),
	INDEX (sid),
	KEY subnetid (subnetid),
	KEY theusual (sid,uid,points,cid),
	KEY countreplies (sid,pid)
) TYPE = myisam;

#
# Table structure for table 'comment_text'
#

DROP TABLE IF EXISTS comment_text;
CREATE TABLE comment_text (
	cid mediumint UNSIGNED NOT NULL,
	comment text NOT NULL,
	FOREIGN KEY (cid) REFERENCES comments(cid),
	PRIMARY KEY (cid)
) TYPE = myisam;

#
# Table structure for table 'content_filters'
#

DROP TABLE IF EXISTS content_filters;
CREATE TABLE content_filters (
	filter_id tinyint UNSIGNED NOT NULL auto_increment,
	form varchar(20) DEFAULT '' NOT NULL,
	regex varchar(100) DEFAULT '' NOT NULL,
	modifier varchar(5) DEFAULT '' NOT NULL,
	field varchar(20) DEFAULT '' NOT NULL,
	ratio float(6,4) DEFAULT '0.0000' NOT NULL,
	minimum_match mediumint(6) DEFAULT '0' NOT NULL,
	minimum_length mediumint DEFAULT '0' NOT NULL,
	err_message varchar(150) DEFAULT '',
	PRIMARY KEY (filter_id),
	KEY form (form),
	KEY regex (regex),
	KEY field_key (field)
) TYPE = myisam;

#
# Table structure for table 'dateformats'
#

DROP TABLE IF EXISTS dateformats;
CREATE TABLE dateformats (
	id tinyint UNSIGNED DEFAULT '0' NOT NULL,
	format varchar(32),
	description varchar(64),
	PRIMARY KEY (id)
) TYPE = myisam;

#
# Table structure for table 'discussions'
#

DROP TABLE IF EXISTS discussions;
CREATE TABLE discussions (
	id mediumint UNSIGNED NOT NULL auto_increment, 
	sid char(16) DEFAULT '' NOT NULL,
	title varchar(128) NOT NULL,
	url varchar(255) NOT NULL,
	topic smallint UNSIGNED NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	type enum("open","recycle","archived") DEFAULT 'open' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	commentcount smallint UNSIGNED DEFAULT '0' NOT NULL,
	flags enum("ok","delete","dirty") DEFAULT 'ok' NOT NULL,
	section varchar(30) NOT NULL,
	KEY (sid),
	FOREIGN KEY (sid) REFERENCES stories(sid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	FOREIGN KEY (topic) REFERENCES topics(tid),
	INDEX (type,uid,ts),
	PRIMARY KEY (id)
) TYPE = myisam;

#
# Table structure for table 'formkeys'
#

DROP TABLE IF EXISTS formkeys;
CREATE TABLE formkeys (
	formkey varchar(20) DEFAULT '' NOT NULL,
	formname varchar(20) DEFAULT '' NOT NULL,
	id varchar(30) DEFAULT '' NOT NULL,
	idcount mediumint UNSIGNED DEFAULT 0 NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	ipid	char(32) DEFAULT '' NOT NULL,
	subnetid	char(32) DEFAULT '' NOT NULL,
	value tinyint DEFAULT '0' NOT NULL,
	last_ts int UNSIGNED DEFAULT '0' NOT NULL,
	ts int UNSIGNED DEFAULT '0' NOT NULL,
	submit_ts int UNSIGNED DEFAULT '0' NOT NULL,
	content_length smallint UNSIGNED DEFAULT '0' NOT NULL,
	PRIMARY KEY (formkey),
	FOREIGN KEY (uid) REFERENCES users(uid),
	KEY formname (formname),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY idcount (idcount),
	KEY ts (ts),
	KEY last_ts (ts),
	KEY submit_ts (submit_ts)
) TYPE = myisam;

#
# Table structure for table 'menus'
#

DROP TABLE IF EXISTS menus;
CREATE TABLE menus (
	id mediumint(5) UNSIGNED NOT NULL auto_increment,
	menu varchar(20) DEFAULT '' NOT NULL,
	label varchar(200) DEFAULT '' NOT NULL,
	value text,
	seclev mediumint UNSIGNED NOT NULL,
	menuorder mediumint(5),
	PRIMARY KEY (id),
	KEY page_labels (menu,label),
	UNIQUE page_labels_un (menu,label)
) TYPE = myisam;

#
# Table structure for table 'metamodlog'
#

DROP TABLE IF EXISTS metamodlog;
CREATE TABLE metamodlog (
	mmid mediumint DEFAULT '0' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	val tinyint  DEFAULT '0' NOT NULL,
	ts datetime,
	id mediumint UNSIGNED NOT NULL auto_increment,
	flag mediumint DEFAULT '0' NOT NULL,
	INDEX byuser (uid),
	PRIMARY KEY (id)
) TYPE = myisam;

#
# Table structure for table 'misc_user_opts'
#

DROP TABLE IF EXISTS misc_user_opts;
CREATE TABLE misc_user_opts (
	name varchar(32) NOT NULL,
	optorder mediumint(5),
	seclev mediumint UNSIGNED NOT NULL,
	default_val text DEFAULT '' NOT NULL,
	vals_regex text DEFAULT '',
	short_desc text DEFAULT '',
	long_desc text DEFAULT '',
	opts_html text DEFAULT '',
	PRIMARY KEY (name)
) TYPE = myisam;

#
# Table structure for table 'moderatorlog'
#

DROP TABLE IF EXISTS moderatorlog;
CREATE TABLE moderatorlog (
	id int UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	val tinyint DEFAULT '0' NOT NULL,
	sid mediumint UNSIGNED DEFAULT '' NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	cid mediumint UNSIGNED NOT NULL,
	cuid mediumint UNSIGNED NOT NULL,
	reason tinyint UNSIGNED DEFAULT '0',
	active tinyint DEFAULT '1' NOT NULL,
	m2count mediumint UNSIGNED DEFAULT '0' NOT NULL,
	PRIMARY KEY (id),
	KEY sid (sid,cid),
	KEY sid_2 (sid,uid,cid),
	KEY cid (cid)
) TYPE = myisam;


#
# Table structure for table 'pollanswers'
#

DROP TABLE IF EXISTS pollanswers;
CREATE TABLE pollanswers (
	qid mediumint NOT NULL,
	aid mediumint NOT NULL,
	answer char(255),
	votes mediumint,
	FOREIGN KEY (qid) REFERENCES pollquestions(qid),
	PRIMARY KEY (qid,aid)
) TYPE = myisam;

#
# Table structure for table 'pollquestions'
#

DROP TABLE IF EXISTS pollquestions;
CREATE TABLE pollquestions (
	qid mediumint UNSIGNED NOT NULL auto_increment,
	sid char(16),
	question char(255) NOT NULL,
	voters mediumint,
	topic smallint UNSIGNED NOT NULL,
	discussion mediumint,
	date datetime,
	uid mediumint UNSIGNED NOT NULL,
	section varchar(30) NOT NULL,
	FOREIGN KEY (discussion) REFERENCES discussions(id),
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (qid)
) TYPE = myisam;

#
# Table structure for table 'pollvoters'
#

DROP TABLE IF EXISTS pollvoters;
CREATE TABLE pollvoters (
	qid mediumint NOT NULL,
	id char(35) NOT NULL,
	time datetime,
	uid mediumint UNSIGNED NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid),
	FOREIGN KEY (qid) REFERENCES pollquestions(qid),
	KEY qid (qid,id,uid)
) TYPE = myisam;

#
# Table structure for table 'related_links'
#

DROP TABLE IF EXISTS related_links;
CREATE TABLE related_links (
	id smallint UNSIGNED NOT NULL auto_increment,
	keyword varchar(30) NOT NULL,
	name varchar(30) NOT NULL,
	link varchar(128) NOT NULL,
	KEY (keyword),
	PRIMARY KEY (id)
) TYPE = myisam;

#
# Table structure for table 'sections'
#

DROP TABLE IF EXISTS sections;
CREATE TABLE sections (
	id smallint UNSIGNED NOT NULL auto_increment,
	section varchar(30) NOT NULL,
	artcount mediumint DEFAULT '30' NOT NULL,
	title varchar(64),
	qid mediumint,
	isolate tinyint DEFAULT '0' NOT NULL,
	issue tinyint DEFAULT '0' NOT NULL,
	extras mediumint DEFAULT '0',
	feature_story char(16) NOT NULL,
	KEY (section),
	FOREIGN KEY (qid) REFERENCES pollquestions(qid),
	FOREIGN KEY (feature_story) REFERENCES stories(sid),
	PRIMARY KEY (id)
) TYPE = myisam;

#
# Table structure for table 'section_extras'
#

DROP TABLE IF EXISTS section_extras;
CREATE TABLE section_extras (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	section varchar(30) NOT NULL,
	name varchar(100) NOT NULL,
	value varchar(100) NOT NULL,
	FOREIGN KEY (section) REFERENCES sections(section),
	UNIQUE extra (section,name),
	PRIMARY KEY (param_id)
) TYPE = myisam;


#
# Table structure for table 'section_topics'
#

DROP TABLE IF EXISTS section_topics;
CREATE TABLE section_topics (
	section varchar(30) NOT NULL,
	tid smallint UNSIGNED NOT NULL,
	FOREIGN KEY (section) REFERENCES sections(section),
	FOREIGN KEY (tid) REFERENCES topics(tid),
	PRIMARY KEY (section,tid)
) TYPE = myisam;

#
# Table structure for table 'sessions'
#

DROP TABLE IF EXISTS sessions;
CREATE TABLE sessions (
	session mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED,
	logintime datetime,
	lasttime datetime,
	lasttitle varchar(50),
	INDEX (uid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (session)
) TYPE = myisam;

DROP TABLE IF EXISTS site_info;
CREATE TABLE site_info (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	name varchar(50) NOT NULL,
	value varchar(200) NOT NULL,
	description varchar(255),
	UNIQUE site_keys (name,value),
	PRIMARY KEY (param_id)
) TYPE = myisam;


#
# Table structure for table 'spamarmors'
#

DROP TABLE IF EXISTS spamarmors;
CREATE TABLE spamarmors (
	armor_id mediumint UNSIGNED NOT NULL auto_increment,
	name varchar(40) default NULL,
	code text,
	active mediumint default '1',
	PRIMARY KEY  (armor_id)
) TYPE=MyISAM;


#
# Table structure for table 'stories'
#

DROP TABLE IF EXISTS stories;
CREATE TABLE stories (
	sid char(16) NOT NULL,
	tid smallint UNSIGNED NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	title varchar(100) DEFAULT '' NOT NULL,
	dept varchar(100),
	time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	hits mediumint UNSIGNED DEFAULT '0' NOT NULL,
	section varchar(30) DEFAULT '' NOT NULL,
	displaystatus tinyint DEFAULT '0' NOT NULL,
	commentstatus tinyint,
	discussion mediumint UNSIGNED,
	submitter mediumint UNSIGNED NOT NULL,
	commentcount smallint UNSIGNED DEFAULT '0' NOT NULL,
	hitparade varchar(64) DEFAULT '0,0,0,0,0,0,0' NOT NULL,
	writestatus ENUM("ok","delete","dirty","archived") DEFAULT 'ok' NOT NULL,
	PRIMARY KEY (sid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	FOREIGN KEY (tid) REFERENCES topics(tid),
	FOREIGN KEY (section) REFERENCES sections(section),
	INDEX frontpage (time, displaystatus, writestatus),
	INDEX time (time),
	INDEX submitter (submitter)
) TYPE = myisam;

#
# Table structure for table 'stories'
#

DROP TABLE IF EXISTS story_text;
CREATE TABLE story_text (
	sid char(16) NOT NULL,
	introtext text,
	bodytext text,
	relatedtext text,
	FOREIGN KEY (sid) REFERENCES stories(sid),
	PRIMARY KEY (sid)
) TYPE = myisam;

#
# Table structure for table 'story_param'
#

DROP TABLE IF EXISTS story_param;
CREATE TABLE story_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	sid char(16) NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE story_key (sid,name),
	PRIMARY KEY (param_id)
) TYPE = myisam;

#
# Table structure for table 'story_topics'
#

DROP TABLE IF EXISTS story_topics;
CREATE TABLE story_topics (
  id int(5) NOT NULL auto_increment,
  sid varchar(16) NOT NULL default '',
  tid smallint(5) unsigned default NULL,
  FOREIGN KEY (sid) REFERENCES stories(sid),
  FOREIGN KEY (tid) REFERENCES topics(tid),
  PRIMARY KEY  (id),
  INDEX sid (sid),
  INDEX tid (tid),
  INDEX sidtid (sid,tid)
) TYPE=MyISAM;

#
# Table structure for table 'string_param'
#

DROP TABLE IF EXISTS string_param;
CREATE TABLE string_param (
	param_id smallint UNSIGNED NOT NULL auto_increment,
	type varchar(16) NOT NULL,
	code varchar(16) NOT NULL,
	name varchar(32) NOT NULL,
	UNIQUE code_key (type,code),
	PRIMARY KEY (param_id)
) TYPE = myisam;

#
# Table structure for table 'submissions'
#

DROP TABLE IF EXISTS submissions;
CREATE TABLE submissions (
	subid varchar(15) NOT NULL,
	email varchar(50) NOT NULL,
	name varchar(50) NOT NULL,
	time datetime NOT NULL,
	subj varchar(50) NOT NULL,
	story text NOT NULL,
	tid smallint NOT NULL,
	note varchar(30) DEFAULT '' NOT NULL,
	section varchar(30) DEFAULT '' NOT NULL,
	comment varchar(255) NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	del tinyint DEFAULT '0' NOT NULL,
	PRIMARY KEY (subid),
	FOREIGN KEY (tid) REFERENCES topics(tid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	INDEX (del,section,note),
	INDEX (uid),
	KEY subid (subid,section),
	KEY ipid (ipid),
	KEY subnetid (subnetid)

) TYPE = myisam;

#
# Table structure for table 'submission_param'
#

DROP TABLE IF EXISTS submission_param;
CREATE TABLE submission_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	subid varchar(15) NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE submission_key (subid,name),
	PRIMARY KEY (param_id)
) TYPE = myisam;

#
# Table structure for table 'templates'
#
DROP TABLE IF EXISTS templates;
CREATE TABLE templates (
	tpid mediumint UNSIGNED NOT NULL auto_increment,
	name varchar(30) NOT NULL,
	page varchar(20) DEFAULT 'misc' NOT NULL,
	section varchar(30) DEFAULT 'default' NOT NULL,
	lang char(5) DEFAULT 'en_US' NOT NULL,
	template text,
	seclev mediumint UNSIGNED NOT NULL,
	description text,
	title varchar(128),
	PRIMARY KEY (tpid),
	UNIQUE true_template (name,page,section,lang)
) TYPE = myisam;
#
# Table structure for table 'topics'
#

DROP TABLE IF EXISTS topics;
CREATE TABLE topics (
	tid smallint UNSIGNED NOT NULL auto_increment,
	name char(20) NOT NULL,
	image varchar(100),
	alttext char(40),
	width smallint UNSIGNED,
	height smallint UNSIGNED,
	PRIMARY KEY (tid)
) TYPE = myisam;

#
# Table structure for table 'tzcodes'
#

DROP TABLE IF EXISTS tzcodes;
CREATE TABLE tzcodes (
	tz char(4) DEFAULT '' NOT NULL,
	off_set mediumint,
	description varchar(64),
	PRIMARY KEY (tz)
) TYPE = myisam;

#
# Table structure for table 'users'
#

DROP TABLE IF EXISTS users;
CREATE TABLE users (
	uid mediumint UNSIGNED NOT NULL auto_increment,
	nickname varchar(20) DEFAULT '' NOT NULL,
	realemail varchar(50) DEFAULT '' NOT NULL,
	fakeemail varchar(75),
	homepage varchar(100),
	passwd char(32) DEFAULT '' NOT NULL,
	sig varchar(160),
	seclev mediumint UNSIGNED DEFAULT '0' NOT NULL,	/* This is set to 0 as a safety factor */
	matchname varchar(20),
	newpasswd varchar(8),
	journal_last_entry_date datetime,
	author tinyint DEFAULT 0 NOT NULL,
	PRIMARY KEY (uid),
	KEY login (uid,passwd,nickname),
	KEY chk4user (nickname,realemail),
	KEY nickname_lookup (nickname),
	KEY chk4email (realemail),
	KEY chk4matchname (matchname),
	KEY author_lookup (author)
) TYPE = myisam;

#
# Table structure for table 'users_acl'
#

DROP TABLE IF EXISTS users_acl;
CREATE TABLE users_acl (
	id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	name varchar(32) NOT NULL,
	value varchar(254),
	UNIQUE uid_key (uid,name),
	KEY uid (uid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (id)
) TYPE = myisam;


#
# Table structure for table 'users_comments'
#

DROP TABLE IF EXISTS users_comments;
CREATE TABLE users_comments (
	uid mediumint UNSIGNED NOT NULL,
	points smallint UNSIGNED DEFAULT '0' NOT NULL,
	posttype mediumint DEFAULT '2' NOT NULL,
	defaultpoints tinyint DEFAULT '1' NOT NULL,
	highlightthresh tinyint DEFAULT '4' NOT NULL,
	maxcommentsize smallint UNSIGNED DEFAULT '4096' NOT NULL,
	hardthresh tinyint DEFAULT '0' NOT NULL,
	clbig smallint UNSIGNED DEFAULT '0' NOT NULL,
	clsmall smallint UNSIGNED DEFAULT '0' NOT NULL,
	reparent tinyint DEFAULT '1' NOT NULL,
	nosigs tinyint DEFAULT '0' NOT NULL,
	commentlimit smallint UNSIGNED DEFAULT '100' NOT NULL,
	commentspill smallint UNSIGNED DEFAULT '50' NOT NULL,
	commentsort tinyint DEFAULT '0',
	noscores tinyint DEFAULT '0' NOT NULL,
	mode varchar(10) DEFAULT 'thread',
	threshold tinyint DEFAULT '0',
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'users_count'
#

DROP TABLE IF EXISTS users_count;
CREATE TABLE users_count (
	uid mediumint UNSIGNED NOT NULL,
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'users_hits'
#

DROP TABLE IF EXISTS users_hits;
CREATE TABLE users_hits (
	uid mediumint UNSIGNED NOT NULL,
	lastclick TIMESTAMP,
	hits int DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'users_index'
#

DROP TABLE IF EXISTS users_index;
CREATE TABLE users_index (
	uid mediumint UNSIGNED NOT NULL,
	extid varchar(255),
	exaid varchar(100),
	exsect varchar(255),
	exboxes varchar(255),
	maxstories tinyint UNSIGNED DEFAULT '30' NOT NULL,
	noboxes tinyint DEFAULT '0' NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'users_info'
#

DROP TABLE IF EXISTS users_info;
CREATE TABLE users_info (
	uid mediumint UNSIGNED NOT NULL,
	totalmods mediumint DEFAULT '0' NOT NULL,
	realname varchar(50),
	bio text,
	tokens mediumint DEFAULT '0' NOT NULL,
	lastgranted date DEFAULT '0000-00-00' NOT NULL,
	karma mediumint DEFAULT '0' NOT NULL,
	maillist tinyint DEFAULT '0' NOT NULL,
	totalcomments mediumint UNSIGNED DEFAULT '0',
	lastmm date DEFAULT '0000-00-00' NOT NULL,
	lastaccess date DEFAULT '0000-00-00' NOT NULL,
	lastmmid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2fair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2unfair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2fairvotes mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2unfairvotes mediumint UNSIGNED DEFAULT '0' NOT NULL,
	upmods mediumint UNSIGNED DEFAULT '0' NOT NULL,
	downmods mediumint UNSIGNED DEFAULT '0' NOT NULL,
	session_login tinyint DEFAULT '0' NOT NULL,
	registered tinyint UNSIGNED DEFAULT '1' NOT NULL,
	reg_id char(32) DEFAULT '' NOT NULL,
	expiry_days smallint UNSIGNED DEFAULT '1' NOT NULL,
	expiry_comm smallint UNSIGNED DEFAULT '1' NOT NULL,
	user_expiry_days smallint UNSIGNED DEFAULT '1' NOT NULL,
	user_expiry_comm smallint UNSIGNED DEFAULT '1' NOT NULL,
	created_at datetime DEFAULT '0000-00-00 00:00' NOT NULL,
	people blob,
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'users_param'
#

DROP TABLE IF EXISTS users_param;
CREATE TABLE users_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE uid_key (uid,name),
	KEY (uid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (param_id)
) TYPE = myisam;

#
# Table structure for table 'users_prefs'
#

DROP TABLE IF EXISTS users_prefs;
CREATE TABLE users_prefs (
	uid mediumint UNSIGNED NOT NULL,
	willing tinyint DEFAULT '1' NOT NULL,
	dfid tinyint UNSIGNED DEFAULT '0' NOT NULL,
	tzcode char(4) DEFAULT 'EDT' NOT NULL,
	noicons tinyint DEFAULT '0' NOT NULL,
	light tinyint DEFAULT '0' NOT NULL,
	mylinks varchar(255) DEFAULT '' NOT NULL,
	lang char(5) DEFAULT 'en_US' NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid),
	PRIMARY KEY (uid)
) TYPE = myisam;

#
# Table structure for table 'vars'
#

DROP TABLE IF EXISTS vars;
CREATE TABLE vars (
	name varchar(32) DEFAULT '' NOT NULL,
	value text,
	description varchar(255),
	PRIMARY KEY (name)
) TYPE = myisam;

