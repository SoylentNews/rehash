# MySQL dump 8.10
#
# Host: localhost    Database: dump
#--------------------------------------------------------
# Server version	3.23.26-beta-log

#
# Dumping data for table 'abusers'
#


#
# Dumping data for table 'accesslog'
#


#
# Dumping data for table 'backup_blocks'
#


#
# Dumping data for table 'blocks'
#



#
# Dumping data for table 'code_param'
#

INSERT INTO code_param (type, code, name) VALUES ('blocktype',1,'color');
INSERT INTO code_param (type, code, name) VALUES ('blocktype',2,'static');
INSERT INTO code_param (type, code, name) VALUES ('blocktype',3,'portald');
INSERT INTO code_param (type, code, name) VALUES ('commentcodes',0,'Comments Enabled');
INSERT INTO code_param (type, code, name) VALUES ('commentcodes',1,'Read-Only');
INSERT INTO code_param (type, code, name) VALUES ('commentcodes',-1,'Comments Disabled');
INSERT INTO code_param (type, code, name) VALUES ('discussiontypes',0,'Discussion Enabled');
INSERT INTO code_param (type, code, name) VALUES ('discussiontypes',1,'Recycle Discussion');
INSERT INTO code_param (type, code, name) VALUES ('discussiontypes',2,'Read Only Discussion');
INSERT INTO code_param (type, code, name) VALUES ('displaycodes',0,'Always Display');
INSERT INTO code_param (type, code, name) VALUES ('displaycodes',1,'Only Display Within Section');
INSERT INTO code_param (type, code, name) VALUES ('displaycodes',-1,'Never Display');
INSERT INTO code_param (type, code, name) VALUES ('isolatemodes',0,'Part of Site');
INSERT INTO code_param (type, code, name) VALUES ('isolatemodes',1,'Standalone');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',0,'Neither');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',1,'Article Based');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',2,'Issue Based');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',3,'Both Issue and Article');
INSERT INTO code_param (type, code, name) VALUES ('maillist',0,'Don\'t Email');
INSERT INTO code_param (type, code, name) VALUES ('maillist',1,'Email Headlines Each Night');
INSERT INTO code_param (type, code, name) VALUES ('session_login',0,'Expires after one year');
INSERT INTO code_param (type, code, name) VALUES ('session_login',1,'Expires after browser exits');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',0,'Oldest First');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',1,'Newest First');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',3,'Highest Scores First');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',4,'Oldest First (Ignore Threads)');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',5,'Newest First (Ignore Threads)');
INSERT INTO code_param (type, code, name) VALUES ('sortorder',1,'Order By Date');
INSERT INTO code_param (type, code, name) VALUES ('sortorder',2,'Order By Score');
INSERT INTO code_param (type, code, name) VALUES ('statuscodes',1,'Refreshing');
INSERT INTO code_param (type, code, name) VALUES ('statuscodes',0,'Normal');
INSERT INTO code_param (type, code, name) VALUES ('statuscodes',10,'Archive');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',-1,'-1: Uncut and Raw');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',0,'0: Almost Everything');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',1,'1: Filter Most ACs');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',2,'2: Score +2');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',3,'3: Score +3');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',4,'4: Score +4');
INSERT INTO code_param (type, code, name) VALUES ('threshcodes',5,'5: Score +5');
INSERT INTO code_param (type, code, name) VALUES ('postmodes',1,'Plain Old Text');
INSERT INTO code_param (type, code, name) VALUES ('postmodes',2,'HTML Formatted');
INSERT INTO code_param (type, code, name) VALUES ('postmodes',3,'Extrans (html tags to text)');
INSERT INTO code_param (type, code, name) VALUES ('postmodes',4,'Code');
INSERT INTO code_param (type, code, name) VALUES ('section_topic_types',1,'default');

#
# Dumping data for table 'commentmodes'
#

INSERT INTO commentmodes (mode, name, description) VALUES ('flat','Flat','');
INSERT INTO commentmodes (mode, name, description) VALUES ('nested','Nested','');
INSERT INTO commentmodes (mode, name, description) VALUES ('thread','Threaded','');
INSERT INTO commentmodes (mode, name, description) VALUES ('nocomment','No Comments','');

#
# Dumping data for table 'comments'
#


#
# Dumping data for table 'comment_text'
#


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
# Table structure for table 'hooks'
#

DROP TABLE IF EXISTS hooks;
CREATE TABLE hooks (
	id mediumint(5) UNSIGNED NOT NULL auto_increment,
	param varchar(50) DEFAULT '' NOT NULL,
	class varchar(100) DEFAULT '' NOT NULL,
	subroutine varchar(100) DEFAULT '' NOT NULL,
	PRIMARY KEY (id),
	UNIQUE hook_param (param,class,subroutine)
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
	question char(255) NOT NULL,
	voters mediumint,
	topic smallint UNSIGNED NOT NULL,
	discussion mediumint,
	date datetime,
	uid mediumint UNSIGNED NOT NULL,
	section varchar(30) NOT NULL,
	FOREIGN KEY (section) REFERENCES sections(section),
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
	url char(128) DEFAULT '' NOT NULL,
	hostname char(128) DEFAULT '' NOT NULL,
	cookiedomain char(128) DEFAULT '' NOT NULL,
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
	type enum("text","list") DEFAULT 'text' NOT NULL,
	list varchar(255) DEFAULT '' NOT NULL,
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
	type smallint UNSIGNED NOT NULL,
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
	last_subid varchar(15),
	last_sid varchar(16),
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
	day_published date DEFAULT '0000-00-00' NOT NULL,
	qid MEDIUMINT UNSIGNED DEFAULT NULL,
	PRIMARY KEY (sid),
	FOREIGN KEY (uid) REFERENCES users(uid),
	FOREIGN KEY (tid) REFERENCES topics(tid),
	FOREIGN KEY (section) REFERENCES sections(section),
	FOREIGN KEY (qid) REFERENCES pollquestions(qid),
	INDEX frontpage (displaystatus, writestatus,section),
	INDEX time (time), /* time > now() shows that this is still valuable, even with frontpage -Brian */
	INDEX submitter (submitter),
	INDEX published (day_published)
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
  PRIMARY KEY (id),
  INDEX tid (tid),
  INDEX sid (sid)
) TYPE = myisam;

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
	weight float DEFAULT '0' NOT NULL, 
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
	KEY login (nickname,uid,passwd),
	KEY chk4user (realemail,nickname),
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

#
# Dumping data for table 'content_filters'
#


#
# Dumping data for table 'dateformats'
#

INSERT INTO dateformats (id, format, description) VALUES (0,'%A %B %d, @%I:%M%p','Sunday March 21, @10:00AM');
INSERT INTO dateformats (id, format, description) VALUES (1,'%A %B %d, @%H:%M','Sunday March 21, @23:00');
INSERT INTO dateformats (id, format, description) VALUES (2,'%k:%M %d %B %Y','23:00 21 March 1999');
INSERT INTO dateformats (id, format, description) VALUES (3,'%k:%M %A %d %B %Y','23:00 Sunday 21 March 1999');
INSERT INTO dateformats (id, format, description) VALUES (4,'%I:%M %p -- %A %B %d %Y','9:00 AM -- Sunday March 21 1999');
INSERT INTO dateformats (id, format, description) VALUES (5,'%a %B %d, %k:%M','Sun March 21, 23:00');
INSERT INTO dateformats (id, format, description) VALUES (6,'%a %B %d, %I:%M %p','Sun March 21, 10:00 AM');
INSERT INTO dateformats (id, format, description) VALUES (7,'%m-%d-%y %k:%M','3-21-99 23:00');
INSERT INTO dateformats (id, format, description) VALUES (8,'%d-%m-%y %k:%M','21-3-99 23:00');
INSERT INTO dateformats (id, format, description) VALUES (9,'%m-%d-%y %I:%M %p','3-21-99 10:00 AM');
INSERT INTO dateformats (id, format, description) VALUES (15,'%d/%m/%y %k:%M','21/03/99 23:00');
#INSERT INTO dateformats (id, format, description) VALUES (10,'%I:%M %p  %B %E, %Y','10:00 AM  March 21st, 1999');
INSERT INTO dateformats (id, format, description) VALUES (10,'%I:%M %p  %B %o, %Y','10:00 AM  March 21st, 1999');
#INSERT INTO dateformats (id, format, description) VALUES (11,'%k:%M  %E %B, %Y','23:00  21st March, 1999');
INSERT INTO dateformats (id, format, description) VALUES (11,'%k:%M  %o %B, %Y','23:00  21st March, 1999');
INSERT INTO dateformats (id, format, description) VALUES (12,'%a %b %d, \'%y %I:%M %p','Sun Mar 21, \'99 10:00 AM');
#INSERT INTO dateformats (id, format, description) VALUES (13,'%i ish','6 ish');
INSERT INTO dateformats (id, format, description) VALUES (13,'%l ish','6 ish');
INSERT INTO dateformats (id, format, description) VALUES (14,'%y-%m-%d %k:%M','99-03-19 14:14');
INSERT INTO dateformats (id, format, description) VALUES (16,'%a %d %b %I:%M%p','Sun 21 Mar 10:00AM');
INSERT INTO dateformats (id, format, description) VALUES (17,'%Y.%m.%d %k:%M','1999.03.19 14:14');

#
# Dumping data for table 'discussions'
#


#
# Dumping data for table 'formkeys'
#


#
# Dumping data for table 'hitters'
#


#
# Dumping data for table 'menus'
#


#
# Dumping data for table 'metamodlog'
#


#
# Dumping data for table 'moderatorlog'
#


#
# Dumping data for table 'pollanswers'
#


#
# Dumping data for table 'pollquestions'
#


#
# Dumping data for table 'pollvoters'
#

#
# Dumping data for table 'related_links'
#


#
# Dumping data for table 'sections'
#


#
# Dumping data for table 'section_topics'
#


#
# Dumping data for table 'sessions'
#


#
# Dumping data for table 'site_info'
#
INSERT INTO site_info VALUES ('','form','submissions','user submissions form');
INSERT INTO site_info VALUES ('','form','comments','comments submission form');


#
# Dumping data for table 'stories'
#



#
# Dumping data for table 'story_text'
#

#
# Dumping data for table 'story_param'
#

#
# Dumping data for table 'submissions'
#


#
# Dumping data for table 'templates'
#


#
# Dumping data for table 'topics'
#


#
# Dumping data for table 'tzcodes'
#

INSERT INTO tzcodes (tz, off_set, description) VALUES ('NDT',-9000,'Newfoundland Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ADT',-10800,'Atlantic Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EDT',-14400,'Eastern Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CDT',-18000,'Central Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MDT',-21600,'Mountain Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('PDT',-25200,'Pacific Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('YDT',-28800,'Yukon Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('HDT',-32400,'Hawaii Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('BST',3600,'British Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MES',7200,'Middle European Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('SST',7200,'Swedish Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('FST',7200,'French Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('NZD',46800,'New Zealand Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('GMT',0,'Greenwich Mean');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('UTC',0,'Universal (Coordinated)');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WET',0,'Western European');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WEST',3600,'Western European Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WAT',-3600,'West Africa');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AT',-7200,'Azores');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('GST',-10800,'Greenland Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('NFT',-12600,'Newfoundland');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('NST',-12600,'Newfoundland Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AST',-14400,'Atlantic Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EST',-18000,'Eastern Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CST',-21600,'Central Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MST',-25200,'Mountain Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('PST',-28800,'Pacific Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('YST',-32400,'Yukon Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('HST',-36000,'Hawaii Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CAT',-36000,'Central Alaska');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AHS',-36000,'Alaska-Hawaii Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('NT',-39600,'Nome');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('IDL',-43200,'International Date Line West');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CET',3600,'Central European');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CEST',7200,'Central European Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MET',3600,'Middle European');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MEW',3600,'Middle European Winter');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('SWT',3600,'Swedish Winter');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('FWT',3600,'French Winter');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EET',7200,'Eastern Europe, USSR Zone 1');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EEST',10800,'Eastern Europe Summer');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('BT',10800,'Baghdad, USSR Zone 2');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('IT',12600,'Iran');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ZP4',14400,'USSR Zone 3');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ZP5',18000,'USSR Zone 4');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('IST',19800,'Indian Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ZP6',21600,'USSR Zone 5');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('JT',27000,'Java (3pm in Cronusland!)');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CCT',28800,'China Coast, USSR Zone 7');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WAS',28800,'West Australian Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WAD',32400,'West Australian Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AWST',28800,'Australian Western Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AWDT',32400,'Australian Western Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('JST',32400,'Japan Standard, USSR Zone 8');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CAS',34200,'Central Australian Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CAD',37800,'Central Australian Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ACST',34200,'Australian Central Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ACDT',37800,'Australian Central Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EAS',36000,'Eastern Australian Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EAD',39600,'Eastern Australian Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AEST',36000,'Australian Eastern Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('AEDT',39600,'Australian Eastern Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('NZT',43200,'New Zealand');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('NZS',43200,'New Zealand Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ID2',43200,'International Date Line East');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('IDT',10800,'Israel Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('ISS',7200,'Israel Standard');

#
# Dumping data for table 'users'
#


#
# Dumping data for table 'users_comments'
#


#
# Dumping data for table 'users_index'
#


#
# Dumping data for table 'users_info'
#


#
# Dumping data for table 'users_param'
#


#
# Dumping data for table 'users_prefs'
#


#
# Dumping data for table 'vars'
#

INSERT INTO vars (name, value, description) VALUES ('absolutedir','http://www.example.com','Absolute base URL of site; used for creating links external to site that need a complete URL');
INSERT INTO vars (name, value, description) VALUES ('absolutedir_secure','https://www.example.com','Absolute base URL of Secure HTTP site');
INSERT INTO vars (name, value, description) VALUES ('ad_max', '6', 'Maximum ad number (must be at least ad_messaging_num)');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_num', '6', 'Which ad (env var AD_BANNER_x) is the "messaging ad"?');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_prob', '0.5', 'Probability that the messaging ad will be shown, if the circumstances are right');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_sections', '', 'Vertbar-separated list of sections where messaging ads can appear; if empty, all sections');
INSERT INTO vars (name, value, description) VALUES ('admin_check_clearpass', '0', 'Check whether admins have sent their Slash passwords in the clear?');
INSERT INTO vars (name, value, description) VALUES ('admin_clearpass_disable', '0', 'Should admins who send their Slash passwords in the clear have their admin privileges removed until they change their passwords?');
INSERT INTO vars (name, value, description) VALUES ('admin_secure_ip_regex', '^127\\.', 'IP addresses or networks known to be secure.');
INSERT INTO vars (name, value, description) VALUES ('admin_timeout','30','time in minutes before idle admin session ends');
INSERT INTO vars (name, value, description) VALUES ('adminmail','admin@example.com','All admin mail goes here');
INSERT INTO vars (name, value, description) VALUES ('allow_anonymous','1','allow anonymous posters');
INSERT INTO vars (name, value, description) VALUES ('allow_moderation','1','allows use of the moderation system');
INSERT INTO vars (name, value, description) VALUES ('allow_nonadmin_ssl','0','Allows users with seclev <= 1 to access the site over Secure HTTP');
INSERT INTO vars (name, value, description) VALUES ('anonymous_coward_uid', '1', 'UID to use for anonymous coward');
INSERT INTO vars (name, value, description) VALUES ('apache_cache', '3600', 'Default times for the getCurrentCache().');
INSERT INTO vars (name, value, description) VALUES ('approvedtags','B|I|P|A|LI|OL|UL|EM|BR|TT|STRONG|BLOCKQUOTE|DIV|ECODE','Tags that you can use');
INSERT INTO vars (name, value, description) VALUES ('approvedtags_break','P|LI|OL|UL|BR|BLOCKQUOTE|DIV','Tags that break words (see breakHtml())');
INSERT INTO vars (name, value, description) VALUES ('approved_url_schemes','ftp|http|gopher|mailto|news|nntp|telnet|wais|https','Schemes that can be used in comment links without being stripped of bogus chars');
INSERT INTO vars (name, value, description) VALUES ('archive_delay','60','days to wait for story archiving');
INSERT INTO vars (name, value, description) VALUES ('archive_use_backup_db', '0', 'Should the archival process retrieve data from the backup database?');
INSERT INTO vars (name, value, description) VALUES ('articles_only','0','show only Articles in submission count in admin menu');
INSERT INTO vars (name, value, description) VALUES ('authors_unlimited','1','Authors have unlimited moderation');
INSERT INTO vars (name, value, description) VALUES ('backup_db_user','','The virtual user of the database that the code should use for intensive database access that may bring down the live site. If you don\'t know what this is for, you should leave it blank.');
INSERT INTO vars (name, value, description) VALUES ('badkarma','-10','Users get penalized for posts if karma is below this value');
INSERT INTO vars (name, value, description) VALUES ('badreasons','4','number of \"Bad\" reasons in \"reasons\", skip 0 (which is neutral)');
INSERT INTO vars (name, value, description) VALUES ('banlist_expire','900','Default expiration time for the banlist cache');
INSERT INTO vars (name, value, description) VALUES ('basedir','/usr/local/slash/www.example.com/htdocs','Where should the html/perl files be found?');
INSERT INTO vars (name, value, description) VALUES ('basedomain','www.example.com','The URL for the site');
INSERT INTO vars (name, value, description) VALUES ('block_expire','3600','Default expiration time for the block cache');
INSERT INTO vars (name, value, description) VALUES ('body_bytes','0','Use Slashdot like byte message instead of word count on stories');
INSERT INTO vars (name, value, description) VALUES ('breakhtml_wordlength','50','Maximum word length before whitespace is inserted in comments');
INSERT INTO vars (name, value, description) VALUES ('breaking','100','Establishes the maximum number of comments the system will display when reading comments from a "live" discussion. For stories that exceed this number of comments, there will be "page breaks" printed at the bottom. This setting does not affect "archive" mode.');
INSERT INTO vars (name, value, description) VALUES ('cache_enabled','1','Simple Boolean to determine if content is cached or not');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_debug','1','Debug _comment_text cache activity to STDERR?');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_hours','96','Discussion age at which comments are no longer cached');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_keys','3000','Maximum number of keys in the _comment_text cache');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_newstyle','0','Use _getCommentTextNew?');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_max_frac','0.75','In purging the _comment_text cache, fraction of max_keys to target');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_min_comm','50','Min number comments in a discussion for it to force a cache purge');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_min_req','5','Min number times a discussion must be requested to force a cache purge');
INSERT INTO vars (name, value, description) VALUES ('comment_nonstartwordchars','.,;:/','Chars which cannot start a word (will be forcibly separated from the rest of the word by a space) - this works around a Windows/MSIE "widening" bug - set blank for no action');
INSERT INTO vars (name, value, description) VALUES ('comment_maxscore','5','Maximum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_minscore','-1','Minimum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('commentsPerPoint','1000','For every X comments, valid users get a Moderator Point');
INSERT INTO vars (name, value, description) VALUES ('comments_codemode_wsfactor','0.5','Whitespace factor for CODE posting mode');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_hours','720','Hours after which a comment\'s ipid/subnetid are forgotten; set very large to disable');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_maxrows','100000','Max number of rows to forget IPs of at once');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_mincid','0','Minimum cid to start forgetting IP at');
INSERT INTO vars (name, value, description) VALUES ('comments_hardcoded','0','Turns on hardcoded layout (this is a Slashdot only feature)');
INSERT INTO vars (name, value, description) VALUES ('comments_max_email_len','40','Max num of chars of fakeemail to display in comment header');
INSERT INTO vars (name, value, description) VALUES ('comments_min_line_len','10','Minimum minimum average line length');
INSERT INTO vars (name, value, description) VALUES ('comments_min_line_len_max','20','Maximum minimum average line length');
INSERT INTO vars (name, value, description) VALUES ('comments_min_line_len_kicks_in','100','Num chars at which minimum average line length first takes effect');
INSERT INTO vars (name, value, description) VALUES ('comments_moddable_archived','0','Are comments in discussions that have been archived moderatable?');
INSERT INTO vars (name, value, description) VALUES ('comments_moddable_hours','336','Num hours after being posted that a comment may be moderated');
INSERT INTO vars (name, value, description) VALUES ('comments_response_limit','5','interval between reply and submit');
INSERT INTO vars (name, value, description) VALUES ('comments_speed_limit','120','seconds delay before repeat posting');
INSERT INTO vars (name, value, description) VALUES ('comments_wsfactor','1.0','Whitespace factor');
INSERT INTO vars (name, value, description) VALUES ('commentstatus','0','default comment code');
INSERT INTO vars (name, value, description) VALUES ('cookiedomain','','Domain for cookie to be active (normally leave blank)');
INSERT INTO vars (name, value, description) VALUES ('cookiepath','/','Path on server for cookie to be active');
INSERT INTO vars (name, value, description) VALUES ('cookiesecure','0','Whether or not to set secure flag in cookies if SSL is on (not working)');
INSERT INTO vars (name, value, description) VALUES ('currentqid',1,'The Current Question on the homepage pollbooth');
INSERT INTO vars (name, value, description) VALUES ('daily_attime','00:00:00','Time of day to run dailyStuff (in TZ daily_tz; 00:00:00-23:59:59)');
INSERT INTO vars (name, value, description) VALUES ('daily_last','2000-01-01 01:01:01','Last time dailyStuff was run (GMT)');
INSERT INTO vars (name, value, description) VALUES ('daily_tz','EST','Base timezone for running dailyStuff');
INSERT INTO vars (name, value, description) VALUES ('datadir','/usr/local/slash/www.example.com','What is the root of the install for Slash');
INSERT INTO vars (name, value, description) VALUES ('default_rss_template','default','name of default rss template used by portald');
INSERT INTO vars (name, value, description) VALUES ('defaultcommentstatus','0','default code for article comments- normally 0=posting allowed');
INSERT INTO vars (name, value, description) VALUES ('defaultdisplaystatus','0','Default display status ...');
INSERT INTO vars (name, value, description) VALUES ('defaultsection','articles','Default section to display');
INSERT INTO vars (name, value, description) VALUES ('defaulttopic','1','Default topic to use');
INSERT INTO vars (name, value, description) VALUES ('delete_old_stories', '0', 'Delete stories and discussions that are older than the archive delay.');
INSERT INTO vars (name, value, description) VALUES ('discussion_create_seclev','1','Seclev required to create discussions (yes, this could be an ACL in the future).');
INSERT INTO vars (name, value, description) VALUES ('discussion_default_topic', '1', 'Default topic of user-created discussions.');
INSERT INTO vars (name, value, description) VALUES ('discussion_display_limit', '30', 'Number of default discussions to list.');
INSERT INTO vars (name, value, description) VALUES ('discussionrecycle','0','Default is that recycle never occurs on recycled discussions. This number is valued in days.');
INSERT INTO vars (name, value, description) VALUES ('discussions_speed_limit','300','seconds delay before repeat discussion');
INSERT INTO vars (name, value, description) VALUES ('do_expiry','1','Flag which controls whether we expire users.');
INSERT INTO vars (name, value, description) VALUES ('down_moderations','-6','number of how many comments you can post that get down moderated');
INSERT INTO vars (name, value, description) VALUES ('fancyboxwidth','200','What size should the boxes be in?');
INSERT INTO vars (name, value, description) VALUES ('feature_story_enabled','0','Simple Boolean to determine if homepage prints feature story');
INSERT INTO vars (name, value, description) VALUES ('formkey_timeframe','14400','The time frame that we check for a formkey');
INSERT INTO vars (name, value, description) VALUES ('freshenup_max_stories','100','Maximum number of article.shtml files to write at a time in freshenup.pl');
INSERT INTO vars (name, value, description) VALUES ('goodkarma','25','Users get bonus points for posts if karma above this value');
INSERT INTO vars (name, value, description) VALUES ('http_proxy','','http://proxy.www.example.com');
INSERT INTO vars (name, value, description) VALUES ('id_md5_vislength','5','Num chars to display for ipid/subnetid (0 for all)');
INSERT INTO vars (name, value, description) VALUES ('imagedir','//www.example.com/images','Absolute URL for image directory');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_ip','4','Downmods at which an IP is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_subnet','6','Downmods at which a subnet is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_user','4','Downmods at which a user is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_ipid_hours','72','Hours back that getIsTroll checks IPs for comment mods');
INSERT INTO vars (name, value, description) VALUES ('istroll_uid_hours','72','Hours back that getIsTroll checks uids for comment mods');
INSERT INTO vars (name, value, description) VALUES ('lastComments','0','Last time we checked comments for moderation points');
INSERT INTO vars (name, value, description) VALUES ('lastsrandsec','awards','Last Block used in the semi-random block');
INSERT INTO vars (name, value, description) VALUES ('lenient_formkeys','0','0 - only ipid, 1 - ipid OR subnetid, in formkey validation check');
INSERT INTO vars (name, value, description) VALUES ('log_admin','1','This turns on/off entries to the accesslog. If you are a small site and want a true number for your stats turn this off.');
INSERT INTO vars (name, value, description) VALUES ('logdir','/usr/local/slash/www.example.com/logs','Where should the logs be found?');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_hitcount','3','Number of hits on comments.pl before user can be considered eligible for moderation');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_percentage','0.8','Percentage of users eligible to moderate');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_end', '0.8888', 'Ending percentage into the pool of eligible moderators (used by moderatord)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_start', '0.167', 'Starting percentage into the pool of eligible moderators (used by moderatord)');
INSERT INTO vars (name, value, description) VALUES ('m2_batchsize', 50, 'Maximum number of moderations processed for M2 reconciliation per execution of moderation daemon.');
INSERT INTO vars (name, value, description) VALUES ('m2_bonus','+1','Bonus for participating in meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_comments','10','Number of comments for meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus', 9, 'Number of M2 votes per M1 before it is reconciled by consensus, best if this is an odd number.');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus_trigger', '0.75', 'Weighted average of consensus votes to dissentor votes which determines a "clear victory" in M2.');
INSERT INTO vars (name, value, description) VALUES ('m2_dissension_penalty', '-1', 'Penalty assessed for each "head" of dissension when M2 penalties are triggered.');
INSERT INTO vars (name, value, description) VALUES ('m2_maxbonus','12','Usually 1/2 of goodkarma');
INSERT INTO vars (name, value, description) VALUES ('m2_maxunfair','0.5','Minimum % of unfairs for M2 penalty (deprecated)');
INSERT INTO vars (name, value, description) VALUES ('m2_mincheck','3','Usually 1/3 of m2_comments (deprecated)');
INSERT INTO vars (name, value, description) VALUES ('m2_minority_trigger', '0.05', 'If weighted average of dissension votes to consensus votes is less than this value, this will trigger M2 penalties.');
INSERT INTO vars (name, value, description) VALUES ('m2_modlog_cycles', '0', 'Number of times Metamoderation has processed the entire moderation log.');
INSERT INTO vars (name, value, description) VALUES ('m2_modlog_pos', '0', 'Value of ID of last ID processed by a Meta-Moderator. Basically, this an indicator as to where the next set of M2 comments will be.');
INSERT INTO vars (name, value, description) VALUES ('m2_penalty','-1','Penalty for misuse of meta-moderation (deprecated)');
INSERT INTO vars (name, value, description) VALUES ('m2_reward_pool', '4', 'Amount of point pool to award users participating in M2. Users cannot receive more than 1 point from the point pool.');
INSERT INTO vars (name, value, description) VALUES ('m2_toomanyunfair','0.3','Minimum % of unfairs for which M2 is ignored (deprecated)');
INSERT INTO vars (name, value, description) VALUES ('m2_userpercentage','0.9','UID must be below this percentage of the total userbase to metamoderate');
INSERT INTO vars (name, value, description) VALUES ('mailfrom','admin@example.com','All mail addressed from the site looks like it is coming from here');
INSERT INTO vars (name, value, description) VALUES ('mainfontface','verdana,helvetica,arial','Fonts');
INSERT INTO vars (name, value, description) VALUES ('max_comments_allowed','30','maximum number of posts per day allowed');
INSERT INTO vars (name, value, description) VALUES ('max_comments_unusedfk','10','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_depth','7','max depth for nesting of comments');
INSERT INTO vars (name, value, description) VALUES ('max_discussions_allowed','3','maximum number of posts per day allowed');
INSERT INTO vars (name, value, description) VALUES ('max_discussions_unusedfk','10','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_expiry_comm','250','Largest value for comment expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('max_expiry_days','365','Largest value for duration expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('max_items','15','max number of rss items by default');
INSERT INTO vars (name, value, description) VALUES ('max_submission_size','32000','max size of submission before warning message is displayed');
INSERT INTO vars (name, value, description) VALUES ('max_submissions_allowed','20','maximum number of submissions per timeframe allowed');
INSERT INTO vars (name, value, description) VALUES ('max_submissions_unusedfk','10','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_users_allowed','50','How many changes a user can submit');
INSERT INTO vars (name, value, description) VALUES ('max_users_unusedfk','30','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_users_viewings','30','how many times users.pl can be viewed');
INSERT INTO vars (name, value, description) VALUES ('maxkarma','50','Maximum karma a user can accumulate');
INSERT INTO vars (name, value, description) VALUES ('maxpoints','5','The maximum number of points any moderator can have');
INSERT INTO vars (name, value, description) VALUES ('maxtokens','40','Token threshold that must be hit to get any points');
INSERT INTO vars (name, value, description) VALUES ('metamod_sum','3','sum of moderations 1 for release (deprecated)');
INSERT INTO vars (name, value, description) VALUES ('min_expiry_comm','10','Lowest value for comment expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('min_expiry_days','7','Lowest value for duration expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('minkarma','-25','Minimum karma a user can sink to');
INSERT INTO vars (name, value, description) VALUES ('mod_same_subnet_forbid','1','Forbid users from moderating any comments posted by someone in their subnet?');
INSERT INTO vars (name, value, description) VALUES ('moderatord_catchup_count','2','The number of times moderatord will loop if replication is used and is too far behind our threshold.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_catchup_sleep','2','The number of seconds moderatord will wait each time it loops if replication is behind.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_debug_info', '1', 'Add in more detailed information into slashd.log for moderation task info. This WILL increase the size by slashd.log quite a bit, so use only if you need to.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_lag_threshold','100000','The number of updates replication must be within before moderatord will run using the replicated handle. If this threshold isn\'t met, moderatord will not run.');
INSERT INTO vars (name, value, description) VALUES ('modviewseclev','100','Minimum seclev to see moderation totals on a comment');
INSERT INTO vars (name, value, description) VALUES ('nesting_maxdepth','3','Maximum depth to which <BLOCKQUOTE>-type tags can be nested');
INSERT INTO vars (name, value, description) VALUES ('newsletter_body','0','Print bodytext, not merely introtext, in newsletter.');
INSERT INTO vars (name, value, description) VALUES ('noflush_accesslog','0','DO NOT flush the accesslog table, 0=Flush, 1=No Flush');
INSERT INTO vars (name, value, description) VALUES ('panic','0','0:Normal, 1:No frills, 2:Essentials only');
INSERT INTO vars (name, value, description) VALUES ('poll_cache','0','On home page, cache and display default poll for users (if false, is extra hits to database)');
INSERT INTO vars (name, value, description) VALUES ('poll_discussions','1','Allow discussions on polls');
INSERT INTO vars (name, value, description) VALUES ('rdfencoding','ISO-8859-1','Site encoding');
INSERT INTO vars (name, value, description) VALUES ('rdfimg','http://www.example.com/images/topics/topicslash.gif','site icon to be used by RSS subscribers');
INSERT INTO vars (name, value, description) VALUES ('rdfitemdesc','0','1 == include introtext in item description; 0 == don\'t.  Any other number is substr() of introtext to use');
INSERT INTO vars (name, value, description) VALUES ('rdflanguage','en-us','What language is the site in?');
INSERT INTO vars (name, value, description) VALUES ('rdfpublisher','Me','The \"publisher\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfrights','Copyright &copy; 2000, Me','The \"copyright\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfsubject','Technology','The \"subject\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfupdatebase','1970-01-01T00:00+00:00','The date to use as a base for the updating');
INSERT INTO vars (name, value, description) VALUES ('rdfupdatefrequency','1','How often to update per rdfupdateperiod');
INSERT INTO vars (name, value, description) VALUES ('rdfupdateperiod','hourly','When to update');
INSERT INTO vars (name, value, description) VALUES ('reasons','Normal|Offtopic|Flamebait|Troll|Redundant|Insightful|Interesting|Informative|Funny|Overrated|Underrated','first is neutral, next $badreasons are bad, the last two are \"special\", the rest are good');
INSERT INTO vars (name, value, description) VALUES ('rootdir','//www.example.com','Base URL of site; used for creating on-site links that need protocol-inspecific URL (so site can be used via HTTP and HTTPS at the same time)');
INSERT INTO vars (name, value, description) VALUES ('run_ads','0','Should we be running ads?');
INSERT INTO vars (name, value, description) VALUES ('runtask_verbosity','3','How much information runtask should write to slashd.log: 0-3 or empty string to use slashd_verbosity');
INSERT INTO vars (name, value, description) VALUES ('sbindir','/usr/local/slash/sbin','Where are the sbin scripts kept');
INSERT INTO vars (name, value, description) VALUES ('search_google','0','Turn on to disable local search (and invite users to use google.com)');
INSERT INTO vars (name, value, description) VALUES ('send_mail','1','Turn On/Off to allow the system to send email messages.');
INSERT INTO vars (name, value, description) VALUES ('siteadmin','admin','The admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteadmin_name','Slash Admin','The pretty name for the admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteid','www.example.com','The unique ID for this site');
INSERT INTO vars (name, value, description) VALUES ('sitename','Slash Site','Name of the site');
INSERT INTO vars (name, value, description) VALUES ('siteowner','slash','What user this runs as');
INSERT INTO vars (name, value, description) VALUES ('sitepublisher','Me','The entity that publishes the site');
INSERT INTO vars (name, value, description) VALUES ('slashd_verbosity','2','How much information slashd (and runtask) should write to slashd.log: 0-3, 3 can be a lot');
INSERT INTO vars (name, value, description) VALUES ('slashdir','/usr/local/slash','Directory where Slash was installed');
INSERT INTO vars (name, value, description) VALUES ('slogan','Slash Site','Slogan of the site');
INSERT INTO vars (name, value, description) VALUES ('smtp_server','localhost','The mailserver for the site');
INSERT INTO vars (name, value, description) VALUES ('stats_reports','admin@example.com','Who to send daily stats reports to');
INSERT INTO vars (name, value, description) VALUES ('stir','3','Number of days before unused moderator points expire');
INSERT INTO vars (name, value, description) VALUES ('story_expire','600','Default expiration time for story cache');
INSERT INTO vars (name, value, description) VALUES ('submiss_ts','1','print timestamp in submissions view');
INSERT INTO vars (name, value, description) VALUES ('submiss_view','1','allow users to view submissions queue');
INSERT INTO vars (name, value, description) VALUES ('submission_bonus','3','Bonus given to user if submission is used');
INSERT INTO vars (name, value, description) VALUES ('submissions_speed_limit','300','How fast they can submit');
INSERT INTO vars (name, value, description) VALUES ('submit_categories','Back','Extra submissions categories');
INSERT INTO vars (name, value, description) VALUES ('submit_extra_sort_key', '', 'Provides an additional submission list sorted on the given field name');
INSERT INTO vars (name, value, description) VALUES ('submit_show_weight', '0', 'Display optional weight field in submission admin.');
INSERT INTO vars (name, value, description) VALUES ('template_cache_request','0','Special boolean to cache templates only for a single request');
INSERT INTO vars (name, value, description) VALUES ('template_cache_size','0','Number of templates to store in cache (0 = unlimited)');
INSERT INTO vars (name, value, description) VALUES ('template_post_chomp','0','Chomp whitespace after directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_pre_chomp','0','Chomp whitespace before directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_show_comments', '1', 'Show HTML comments before and after template (see Slash::Display)');
INSERT INTO vars (name, value, description) VALUES ('textarea_cols', '50', 'Default # of columns for content TEXTAREA boxes');
INSERT INTO vars (name, value, description) VALUES ('textarea_rows', '10', 'Default # of rows for content TEXTAREA boxes');
INSERT INTO vars (name, value, description) VALUES ('titlebar_width','100%','The width of the titlebar');
INSERT INTO vars (name, value, description) VALUES ('today','730512','(Obviated) Today converted to days past a long time ago');
INSERT INTO vars (name, value, description) VALUES ('token_retention', '0.25', 'Amount of tokens a user keeps at cleanup time.');
INSERT INTO vars (name, value, description) VALUES ('tokenspercomment','6','Number of tokens to feed the system for each comment');
INSERT INTO vars (name, value, description) VALUES ('tokensperpoint','8','Number of tokens per point');
INSERT INTO vars (name, value, description) VALUES ('totalComments','0','Total number of comments posted');
INSERT INTO vars (name, value, description) VALUES ('totalhits','383','Total number of hits the site has had thus far');
INSERT INTO vars (name, value, description) VALUES ('updatemin','5','do slashd updates, default 5');
INSERT INTO vars (name, value, description) VALUES ('use_dept','1','use \"dept.\" field');
INSERT INTO vars (name, value, description) VALUES ('user_comment_display_default','24','Number of comments to display on user\'s info page');
INSERT INTO vars (name, value, description) VALUES ('user_submitter_display_default','24','Number of stories to display on user\'s info page');
INSERT INTO vars (name, value, description) VALUES ('users_show_info_seclev','0','Minimum seclev to view a user\s info');
INSERT INTO vars (name, value, description) VALUES ('users_speed_limit','20','How fast a user can change their prefs');
INSERT INTO vars (name, value, description) VALUES ('writestatus','ok','Simple Boolean to determine if homepage needs rewriting');
INSERT INTO vars (name, value, description) VALUES ('multitopics_enabled','0','whether or not to allow stories to have multiple topics');
