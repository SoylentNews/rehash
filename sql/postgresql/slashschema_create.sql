CREATE TABLE abusers (
	abuser_id SERIAL,
	host_name varchar(25) DEFAULT '' NOT NULL,
	pagename varchar(20) DEFAULT '' NOT NULL,
	ts datetime  DEFAULT '1970-01-01 00:00:00' NOT NULL,
	reason varchar(120) DEFAULT '' NOT NULL,
	querystring varchar(200) DEFAULT '' NOT NULL,
	PRIMARY KEY (abuser_id)
);
CREATE INDEX idx_host_name ON abusers(host_name);
CREATE INDEX idx_reason ON abusers(reason);




CREATE TABLE accesslog (
	id SERIAL,
	host_addr varchar(16) DEFAULT '' NOT NULL,
	op varchar(8),
	dat varchar(32),
	uid int4 NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	query_string varchar(50),
	user_agent varchar(50),
	PRIMARY KEY (id)
);

CREATE TABLE backup_blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	PRIMARY KEY (bid)
);

CREATE TABLE blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	seclev int2,
	type varchar(20) DEFAULT '' NOT NULL,
	description text,
	section varchar(30) DEFAULT '' NOT NULL,
	ordernum int2 DEFAULT '0',
	title varchar(128),
	portal int2 DEFAULT '0',
	url varchar(128),
	rdf varchar(255),
	retrieve int2 DEFAULT '0',
	PRIMARY KEY (bid)
);
CREATE INDEX idx_section ON blocks(section);
CREATE INDEX idx_type ON blocks(type);


CREATE TABLE code_param (
	param_id SERIAL,
	type varchar(16),
	code int2 DEFAULT '0' NOT NULL,
	name varchar(32),
	UNIQUE (type,code),
	PRIMARY KEY (param_id)
);

CREATE TABLE commentmodes (
	mode varchar(16) DEFAULT '' NOT NULL,
	name varchar(32),
	description varchar(64),
	PRIMARY KEY (mode)
);




CREATE TABLE comments (
	sid char(16) DEFAULT '' NOT NULL,
	cid int4 DEFAULT '0' NOT NULL,
	pid int4 DEFAULT '0' NOT NULL,
	date datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	host_name varchar(30) DEFAULT '0.0.0.0' NOT NULL,
	subject varchar(50) DEFAULT '' NOT NULL,
	comment text NOT NULL,
	uid int4 NOT NULL,
	points int2 DEFAULT '0' NOT NULL,
	lastmod int2,
	reason int2 DEFAULT '0',
	PRIMARY KEY (sid,cid)
);
CREATE INDEX idx_display ON comments(sid,points,uid);
CREATE INDEX idx_byname ON comments(uid,points);
CREATE INDEX idx_theusual ON comments(sid,uid,points,cid);
CREATE INDEX idx_countreplies ON comments(sid,pid);




CREATE TABLE content_filters (
	filter_id SERIAL,
  	form varchar(20) DEFAULT ''NOT NULL,
	regex varchar(100) DEFAULT '' NOT NULL,
	modifier varchar(5) DEFAULT '' NOT NULL,
	field varchar(20) DEFAULT '' NOT NULL,
	ratio float4 DEFAULT '0.0000' NOT NULL,
	minimum_match int4 DEFAULT '0' NOT NULL,
	minimum_length int4 DEFAULT '0' NOT NULL,
	err_message varchar(150) DEFAULT '',
	maximum_length int4 DEFAULT '0' NOT NULL,
	PRIMARY KEY (filter_id)
);
CREATE INDEX idx_regex ON content_filters(regex);
CREATE INDEX idx_form ON content_filters(form);
CREATE INDEX idx_field ON content_filters(field);




CREATE TABLE dateformats (
	id int2 DEFAULT '0' NOT NULL,
	format varchar(32),
	description varchar(64),
	PRIMARY KEY (id)
);




CREATE TABLE discussions (
	sid char(16) DEFAULT '' NOT NULL,
	title varchar(128),
	url varchar(128),
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	commentcount int2 DEFAULT '0',
	PRIMARY KEY (sid)
);




CREATE TABLE formkeys (
	formkey varchar(20) DEFAULT '' NOT NULL,
	formname varchar(20) DEFAULT '' NOT NULL,
	id varchar(30) DEFAULT '' NOT NULL,
	sid char(16) DEFAULT '' NOT NULL,
	uid int4 NOT NULL,
	host_name varchar(30) DEFAULT '0.0.0.0' NOT NULL,
	value int4 DEFAULT '0' NOT NULL,
	cid int4 DEFAULT '0' NOT NULL,
	ts int4 DEFAULT '0' NOT NULL,
	submit_ts int4 DEFAULT '0' NOT NULL,
	content_length int2 DEFAULT '0' NOT NULL,
	PRIMARY KEY (formkey)
);
CREATE INDEX idx_formname ON formkeys(formname);
CREATE INDEX idx_id ON formkeys(id);
CREATE INDEX idx_ts ON formkeys(ts);
CREATE INDEX idx_submit_ts ON formkeys(submit_ts);



CREATE TABLE menus (
	id SERIAL,
	menu varchar(20) DEFAULT '' NOT NULL,
	label varchar(200) DEFAULT '' NOT NULL,
	value text,
	seclev int2,
	menuorder int4,
	UNIQUE (menu,label),
	PRIMARY KEY (id)
);

CREATE TABLE metamodlog (
	id SERIAL,
	mmid int4 DEFAULT '0' NOT NULL,
	uid int4 NOT NULL,
	val int4 DEFAULT '0' NOT NULL,
	ts datetime,
	PRIMARY KEY (id)
);




CREATE TABLE moderatorlog (
	id SERIAL,
	uid int4 NOT NULL,
	val int2 DEFAULT '0' NOT NULL,
	sid char(16) DEFAULT '' NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	cid int2 DEFAULT '0' NOT NULL,
	reason int4 DEFAULT '0',
	PRIMARY KEY (id)
);
CREATE INDEX idx_sid ON moderatorlog(sid,cid);
CREATE INDEX idx_sid_2 ON moderatorlog(sid,uid,cid);


CREATE TABLE newstories (
	sid char(16) DEFAULT '' NOT NULL,
	tid varchar(20) DEFAULT '' NOT NULL,
	uid int4 NOT NULL,
	title varchar(100) DEFAULT '' NOT NULL,
	dept varchar(100),
	time datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	introtext text,
	bodytext text,
	writestatus int2 DEFAULT '0' NOT NULL,
	hits int2 DEFAULT '0' NOT NULL,
	section varchar(30) DEFAULT '' NOT NULL,
	displaystatus int2 DEFAULT '0' NOT NULL,
	commentstatus int2,
	hitparade varchar(64) DEFAULT '0,0,0,0,0,0,0',
	relatedtext text,
	extratext text,
	PRIMARY KEY (sid)
);
CREATE INDEX idx_time_new ON newstories(time);
CREATE INDEX idx_searchform_new ON newstories(displaystatus,time);




CREATE TABLE pollanswers (
	qid char(20) DEFAULT '' NOT NULL,
	aid int4 DEFAULT '0' NOT NULL,
	answer char(255),
	votes int4,
	PRIMARY KEY (qid,aid)
);




CREATE TABLE pollquestions (
	qid char(20) DEFAULT '' NOT NULL,
	question char(255) DEFAULT '' NOT NULL,
	voters int4,
	date datetime,
	PRIMARY KEY (qid)
);




CREATE TABLE pollvoters (
	qid char(20) DEFAULT '' NOT NULL,
	id char(35) DEFAULT '' NOT NULL,
	time datetime,
	uid int4 NOT NULL,
	UNIQUE (qid,id,uid)
);
CREATE INDEX idx_qid ON pollvoters(qid,id,uid);





CREATE TABLE postmodes (
	code char(10) DEFAULT '' NOT NULL,
	name char(32),
	PRIMARY KEY (code)
);




CREATE TABLE sections (
	section varchar(30) DEFAULT '' NOT NULL,
	artcount int4,
	title varchar(64),
	qid varchar(20) DEFAULT '' NOT NULL,
	isolate int2,
	issue int2,
	extras int4 DEFAULT '0',
	PRIMARY KEY (section)
);




CREATE TABLE sessions (
	session SERIAL,
	uid int4 NOT NULL,
	logintime datetime,
	lasttime datetime,
	lasttitle varchar(50),
	PRIMARY KEY (session)
);

CREATE TABLE site_info (
  param_id SERIAL,
  name varchar(50) NOT NULL,
  value varchar(200) NOT NULL,
  description varchar(255),
  UNIQUE (name,value),
  PRIMARY KEY (param_id)
);


CREATE TABLE stories (
	sid char(16) DEFAULT '' NOT NULL,
	tid varchar(20) DEFAULT '' NOT NULL,
	uid int4 NOT NULL,
	title varchar(100) DEFAULT '' NOT NULL,
	dept varchar(100),
	time datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	introtext text,
	bodytext text,
	writestatus int2 DEFAULT '0' NOT NULL,
	hits int2 DEFAULT '0' NOT NULL,
	section varchar(30) DEFAULT '' NOT NULL,
	displaystatus int2 DEFAULT '0' NOT NULL,
	commentstatus int2,
	hitparade varchar(64) DEFAULT '0,0,0,0,0,0,0',
	relatedtext text,
	extratext text,
	PRIMARY KEY (sid),
	UNIQUE (time),
	UNIQUE (displaystatus,time)
);
CREATE INDEX idx_time ON stories(time);
CREATE INDEX idx_searchform ON stories(displaystatus,time);

CREATE TABLE story_param (
	param_id SERIAL,
	sid char(16) DEFAULT '' NOT NULL,
	name varchar(32) NOT NULL,
	value varchar(254) NOT NULL,
	UNIQUE (sid, name),
	PRIMARY KEY (param_id)
);




CREATE TABLE storiestuff (
	sid char(16) DEFAULT '' NOT NULL,
	hits int2 DEFAULT '0' NOT NULL,
	PRIMARY KEY (sid)
);




CREATE TABLE submissions (
	subid varchar(15) DEFAULT '' NOT NULL,
	email varchar(50),
	name varchar(50),
	time datetime,
	subj varchar(50),
	story text,
	tid varchar(20),
	note varchar(30),
	section varchar(30) DEFAULT '' NOT NULL,
	comment varchar(255),
	uid int4 NOT NULL,
	del int2 DEFAULT '0' NOT NULL,
	PRIMARY KEY (subid)
);
CREATE INDEX idx_subid ON submissions(subid,section);



CREATE TABLE templates (
	tpid SERIAL,
	name varchar(30) DEFAULT '' NOT NULL,
	page varchar(20) DEFAULT 'misc' NOT NULL,
	section varchar(30) DEFAULT 'default' NOT NULL,
	lang char(5) DEFAULT 'en_US' NOT NULL,
	template text,
	seclev int4,
	description text,
	title varchar(128),
	UNIQUE (name,page,section,lang),
	PRIMARY KEY (tpid)
);



CREATE TABLE topics (
	tid char(20) DEFAULT '' NOT NULL,
	image char(30),
	alttext char(40),
	width int4,
	height int4,
	PRIMARY KEY (tid)
);




CREATE TABLE tzcodes (
	tz char(3) DEFAULT '' NOT NULL,
	off_set int4,
	description varchar(64),
	PRIMARY KEY (tz)
);


CREATE TABLE users (
	uid SERIAL,
	nickname varchar(20) DEFAULT '' NOT NULL,
	realemail varchar(50) DEFAULT '' NOT NULL,
	fakeemail varchar(75),
	homepage varchar(100),
	passwd varchar(32) DEFAULT '' NOT NULL,
	seclev int4 DEFAULT '0' NOT NULL,
	matchname varchar(20),
	newpasswd varchar(32),
	points int4 DEFAULT '0' NOT NULL,
	realname varchar(50),
	tokens int4 DEFAULT '0' NOT NULL,
	lastgranted date DEFAULT '1970-01-01' NOT NULL,
	karma int4 DEFAULT '0' NOT NULL,
	lastmm date DEFAULT '1970-01-01' NOT NULL,
	lastaccess date DEFAULT '1970-01-01' NOT NULL,
  lang char(5) DEFAULT 'en_US' NOT NULL,
	PRIMARY KEY (uid)
);
CREATE INDEX idx_login ON users(uid,passwd,nickname);
CREATE INDEX idx_chk4user ON users(nickname,realemail);
CREATE INDEX idx_chk4email ON users(realemail);

CREATE TABLE users_param (
	param_id SERIAL,
	uid int4 NOT NULL,
	name varchar(32) NOT NULL,
	value text NOT NULL,
	UNIQUE (uid, name),
	PRIMARY KEY (param_id)
);






CREATE TABLE vars (
	name varchar(32) DEFAULT '' NOT NULL,
	value text,
	description varchar(127),
	PRIMARY KEY (name)
);

