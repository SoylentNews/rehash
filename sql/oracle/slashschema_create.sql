/**************************************************
*
*       file: slashdot_schema_8i.sql
*  ported by: toms (guru@oracleplace.com)
*       date: December, 2000
*  copyright: 2000, VALinux
*
*    comment: Entire schema for slashdot system.
*             login into account with resource privileges
*
*    WARNING: This script is destructive, it DROPS and 
*             creates every table in the schema.
*
**************************************************/


spool slashdot_schema_8i.log

prompt drop table abusers
drop table abusers;

/**********************************************
*  TRUNCing a date with no time is redundant
*  but, I wear suspenders with a belt, so.....
***********************************************/

prompt create table abusers
CREATE TABLE abusers (
  abuser_id          number(12),
  user_id 	number (11) NOT NULL,
  ipid          varchar2(32)  DEFAULT '' NOT NULL,
  subnetid          varchar2(32)  DEFAULT '' NOT NULL,
  pagename           varchar2(20)  DEFAULT '' NOT NULL,
  ts                 date          DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  reason             varchar2(120) DEFAULT '' NOT NULL,
  querystring        varchar2(60)  DEFAULT '' NOT NULL,
  constraint abusers_pk PRIMARY KEY (abuser_id)
);

prompt drop sequence abusers_seq
drop sequence abusers_seq;

prompt create sequence abusers_seq
create sequence abusers_seq
    start with 1;

prompt create index idx_user_id
CREATE INDEX idx_user_id ON abusers(user_id);

prompt create index idx_ipid
CREATE INDEX idx_ipid ON abusers(ipid);

prompt create index idx_subnetid
CREATE INDEX idx_subnetid ON abusers(subnetid);

prompt create index idx_reason
CREATE INDEX idx_reason ON abusers(reason);

/**********************************************************
* this table is for accesscontrol and is work in progress
***********************************************************/

prompt drop table accesslist
drop table accesslist;

prompt create table accesslist
CREATE TABLE accesslist (
  id		number(12),
  user_id	number(12),
  ipid		varchar2(32)	DEFAULT '' NOT NULL,
  subnetid	varchar2(32)	DEFAULT '' NOT NULL,
  formname	varchar2(20)	DEFAULT '' NOT NULL,
  readonly	number(4)	DEFAULT '' NOT NULL,
  isbanned	number(4)	DEFAULT '' NOT NULL,
  ts		date		DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  reason	varchar2(120)	DEFAULT '' NOT NULL,
  constraint	accesslist_pk	PRIMARY KEY (id)
);

CREATE INDEX idx_user_id ON accesslist(user_id);
CREATE INDEX idx_ipid ON accesslist(ipid);
CREATE INDEX idx_subnetid ON accesslist(subnetid);
CREATE INDEX idx_formname ON accesslist(formname);
CREATE INDEX idx_ts ON accesslist(ts);

prompt drop sequence accesslist_seq
drop sequence accesslist_seq;

prompt create sequence accesslist_seq
create sequence accesslist_seq
       start with 1;

/**********************************************************
*  IMPORTANT NOTE
*  uid is a reserved word in Oracle
*  the uid has been replaced with user_id
*
*  int4 is not a valid Oracle datatype
*  replaced int4 with Number(12) ie: 12 digits of precision
*
*  int2 is not a valid Oracle datatype
*  replaced int2 with Number(6) ie: 6 digits of precision
*
*  serial is not a valid Oracle datatype
*  replace serial with number(12) and supplied a sequence as
*  table_name_seq.
*
***********************************************************/

prompt drop table accesslog
drop table accesslog;

prompt create table accesslog
CREATE TABLE accesslog (
  id                 number(12),
  host_addr          varchar2(16)  DEFAULT '' NOT NULL,
  op                 varchar2(8),
  dat                varchar2(32),
  user_id            number(12)    NOT NULL,
  ts                 date          DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  query_string       varchar2(50),
  user_agent         varchar2(50),
  constraint accesslog_pk PRIMARY KEY (id)
);

prompt drop sequence accesslog_seq
drop sequence accesslog_seq;

prompt create sequence accesslog_seq
create sequence accesslog_seq
       start with 1;


prompt drop table backup_blocks
drop table backup_blocks;


prompt create table backup_blocks
CREATE TABLE backup_blocks (
	bid       varchar2(30) DEFAULT '' NOT NULL,
	block     clob         default empty_clob(),
	constraint backup_blocks_pk PRIMARY KEY (bid)
);


prompt drop table blocks
drop table blocks;

prompt create table blocks
CREATE TABLE blocks (
  bid         varchar2(30)   DEFAULT '' NOT NULL,
  block       clob           default empty_clob(),
  user_id     number(12),
  seclev      number(12),
  type        varchar2(20)   DEFAULT '' NOT NULL,
  description clob           default empty_clob(),
  section     varchar2(30)   DEFAULT '' NOT NULL,
  ordernum    number(10)     DEFAULT '0',
  title       varchar2(128),
  portal      number(10)     DEFAULT '0',
  url         varchar2(128),
  rdf         varchar2(255),
  retrieve    number(10)     DEFAULT '0',
  constraint blocks_pk PRIMARY KEY (bid)
);


CREATE INDEX idx_section ON blocks(section);
CREATE INDEX idx_type ON blocks(type);


prompt drop table code_param
drop table code_param;

prompt create table code_param
CREATE TABLE code_param (
	param_id      number(12),
	type          varchar2(16),
	code          number(10)    DEFAULT '0' NOT NULL,
	name          varchar2(32),
	constraint code_param_unq UNIQUE (type,code),
	constraint code_param_pk PRIMARY KEY (param_id)
);

prompt drop sequence code_param_seq
drop sequence code_param_seq;

prompt create sequence code_param_seq
create sequence code_param_seq
     start with 1;

prompt drop table commentmodes
drop table commentmodes;

/*********************************************************
*  IMPORTANT NOTE: 
*  mode is a reserved word in Oracle
*  the mode column renamed comment_mode
*
*  date is a reserved word
*  the date column is replaced by comment_date
**********************************************************/

prompt create table commentmodes
CREATE TABLE commentmodes (
  comment_mode varchar2(16)   DEFAULT '' NOT NULL,
  name         varchar2(32),
  description  varchar2(64),
  constraint commentmodes_pk PRIMARY KEY (comment_mode)
);


prompt drop table comments
drop table comments;

/*********************************************************
*  IMPORTANT NOTE: 
*  comment is a reserved word in Oracle
*  comment column renamed comment_text
*
*  date is a reserved word
*  date column is replaced by comment_date
**********************************************************/


prompt create table comments
CREATE TABLE comments (
  sid          varchar2(30)  DEFAULT '' NOT NULL,
  cid          number(12)    DEFAULT 0  NOT NULL,
  pid          number(12)    DEFAULT 0  NOT NULL,
  comment_date date          DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  ipid         char2(32)     DEFAULT '0.0.0.0' NOT NULL,
  subnetid     char2(32)     DEFAULT '0.0.0.0' NOT NULL,
  subject      varchar2(50)  DEFAULT '' NOT NULL,
  comment_text clob          default empty_clob() not null,
  user_id      number(12)    NOT NULL,
  points       number(10)    DEFAULT 0 NOT NULL,
  lastmod      number(10),
  reason       number(10)    DEFAULT 0,
  constraint   comments_pk   PRIMARY KEY (sid,cid)
);


CREATE INDEX idx_display ON comments(sid,points,user_id);
CREATE INDEX idx_byname ON comments(user_id,points);
CREATE INDEX idx_theusual ON comments(sid,user_id,points,cid);
CREATE INDEX idx_countreplies ON comments(sid,pid);
CREATE INDEX idx_ipid	ON comments(ipid);
CREATE INDEX idx_subnetid ON comments(subnetid);


prompt drop table content_filters
drop table content_filters;

prompt create table content_filters
CREATE TABLE content_filters (
  filter_id      number(12),
  form 		varchar2(20) 	  DEFAULT ''NOT NULL,
  regex          varchar2(100)    DEFAULT '' NOT NULL,
  modifier       varchar2(5)      DEFAULT '' NOT NULL,
  field          varchar2(20)     DEFAULT '' NOT NULL,
  ratio          number(16,4)     DEFAULT 0.0000 NOT NULL,
  minimum_match  number(12)       DEFAULT 0 NOT NULL,
  minimum_length number(12)       DEFAULT 0 NOT NULL,
  err_message    varchar2(150)    DEFAULT '',
  constraint contect_filers_pk PRIMARY KEY (filter_id)
);
CREATE INDEX idx_regex ON content_filters(regex);
CREATE INDEX idx_field ON content_filters(field);
CREATE INDEX idx_form ON content_filters(form);

prompt drop sequence content_filters_seq
drop sequence content_filters_seq;

prompt create sequence content_filters_seq
create sequence content_filters_seq
       start with 1;  
       

prompt drop table dateformats
drop table dateformats;

prompt create table dateformats
CREATE TABLE dateformats (
  id            number(12) DEFAULT '0' NOT NULL,
  format        varchar2(32),
  description   varchar2(64),
  constraint dateformats_pk PRIMARY KEY (id)
);


prompt drop table discussions
drop table discussions;

prompt create table discussions
CREATE TABLE discussions (
  sid     varchar2(20)    DEFAULT '' NOT NULL,
  title   varchar2(128),
  url     varchar2(128),
  ts      date            DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  commentcount  number(6)     DEFAULT 0,
  constraint discussions_pk PRIMARY KEY (sid)
);


prompt drop table formkeys
drop table formkeys;

prompt create table formkeys
CREATE TABLE formkeys (
  formkey        varchar2(20) DEFAULT '' NOT NULL,
  formname       varchar2(20) DEFAULT '' NOT NULL,
  id             varchar2(30) DEFAULT '' NOT NULL,
  sid            varchar2(30) DEFAULT '' NOT NULL,
  ipid           char2(32) DEFAULT '0.0.0.0' NOT NULL,
  user_id        number(12)   NOT NULL,
  value          number(10)   DEFAULT 0 NOT NULL,
  cid            number(12)   DEFAULT 0 NOT NULL,
  ts             number(10)   DEFAULT 0 NOT NULL,
  submit_ts      number(10)   DEFAULT 0 NOT NULL,
  content_length number(10)   DEFAULT 0 NOT NULL,
  constraint formkeys PRIMARY KEY (formkey)
);


prompt drop sequence formkeys_seq
drop sequence formkeys_seq;

prompt create sequence formkeys_seq;
create sequence formkeys_seq;

CREATE INDEX idx_formname ON formkeys(formname);
CREATE INDEX idx_id ON formkeys(id);
CREATE INDEX idx_ts ON formkeys(ts);
CREATE INDEX idx_submit_ts ON formkeys(submit_ts);


/**********************************************
*  IMPORTANT NOTE
*  Oracle automatically creates indexes for 
*  columns with a unique constraint, so 
*  indexes do not need to be explicity created.
************************************************/



prompt drop table menus
drop table menus;


prompt create table menus
CREATE TABLE menus (
	id         number(10),
	menu       varchar2(20)   DEFAULT '' NOT NULL,
	label      varchar2(200)  DEFAULT '' NOT NULL,
	value      clob           default empty_clob(),
	seclev     number(12),
	menuorder  number(12),
	constraint mensu_unq UNIQUE (menu,label),
	constraint menus_pk PRIMARY KEY (id)
);


prompt drop table metamodlog
drop table metamodlog;

prompt create table metamodlog
CREATE TABLE metamodlog (
  id           number(12),
  mmid         number(12)  DEFAULT 0 NOT NULL,
  user_id      number(12)  DEFAULT 1 NOT NULL,
  val          number(12)  DEFAULT 0 NOT NULL,
  ts           date,
  constraint metamodlog_pk PRIMARY KEY (id)
);


prompt drop table moderatorlog
drop table moderatorlog;

prompt create table moderatorlog
CREATE TABLE moderatorlog (
  id          number(12),
  user_id     number(12)   DEFAULT 1 NOT NULL,
  val         number(6)    DEFAULT 0 NOT NULL,
  sid         varchar2(30) DEFAULT '' NOT NULL,
  ts          date         DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  cid         number(12)   DEFAULT 0 NOT NULL,
  reason      number(12)   DEFAULT 0,
  constraint moderatorlog_pk PRIMARY KEY (id)
);

CREATE INDEX idx_sid ON moderatorlog(sid,cid);
CREATE INDEX idx_sid_2 ON moderatorlog(sid,user_id,cid);


prompt drop table newstories 
drop table newstories;

prompt create table newstores
CREATE TABLE newstories (
  sid           varchar2(20)  DEFAULT '' NOT NULL,
  tid           varchar2(20)  DEFAULT '' NOT NULL,
  user_id       number(12)    DEFAULT 1 NOT NULL,
  title         varchar2(100) DEFAULT '' NOT NULL,
  dept          varchar2(100),
  time          date          DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  introtext     clob,
  bodytext      clob,
  writestatus   number(6)     DEFAULT 0 NOT NULL,
  hits          number(6)     DEFAULT 0 NOT NULL,
  section       varchar2(15)  DEFAULT '' NOT NULL,
  displaystatus number(6)     DEFAULT 0 NOT NULL,
  commentstatus number(6),
  hitparade     varchar2(64)  DEFAULT '0,0,0,0,0,0,0',
  relatedtext   clob,
  extratext     clob,
  constraint newstories_pk PRIMARY KEY (sid)
);
CREATE INDEX idx_time_new ON newstories(time);
CREATE INDEX idx_searchform_new ON newstories(displaystatus,time);


prompt drop table pollanswers
drop table pollanswers;


/*****************************************************
* IMPORTANT NOTE:
* qid, answer changed from char(20) to varchar2(30)
* in next two tables
*
* char in oracle pads with spaces
* if you want padded spaces, change it back
*****************************************************/

prompt create table pollanswers
CREATE TABLE pollanswers (
  qid      varchar2(20) DEFAULT '' NOT NULL,
  aid      number(12) DEFAULT 0 NOT NULL,
  answer   varchar2(255),
  votes    number(12),
  constraint pollanswers_pk PRIMARY KEY (qid,aid)
);



/***************************************************
* IMPORTANT NOTE
* date is reserved word
* column date changed to poll_que_date
***************************************************/

prompt drop table pollquestions
drop table pollquestions;

prompt create table pollquestions
CREATE TABLE pollquestions (
  qid             varchar2(20) DEFAULT '' NOT NULL,
  question        varchar2(255) DEFAULT '' NOT NULL,
  voters          number(12),
  poll_que_date   date,
  constraint      pollquestions_pk PRIMARY KEY (qid)
);



/******************************************************
*  IMPORTANT NOTE
*  unique constraint automatically indexes columns
*  skipped explicit statement to create idx_qid
*********************************************************/

prompt drop table pollvoters
drop table pollvoters;

prompt create table pollvoters
CREATE TABLE pollvoters (
  qid      varchar2(20) DEFAULT '' NOT NULL,
  id       varchar2(35) DEFAULT '' NOT NULL,
  time     date,
  user_id  number(12) NOT NULL,
  constraint pollvoters_unq UNIQUE (qid,id,user_id)
);


prompt drop table postmodes
drop table postmodes;

prompt create table postmodes
CREATE TABLE postmodes (
  code       varchar2(10) DEFAULT '' NOT NULL,
  name       varchar2(32),
  constraint postmodes_pk PRIMARY KEY (code)
);


prompt drop table sections
drop table sections;

prompt create table sections
CREATE TABLE sections (
  section      varchar2(30) DEFAULT '' NOT NULL,
  artcount     number(12),
  title        varchar2(64),
  qid          varchar2(20) DEFAULT '' NOT NULL,
  isolate      number(6),
  issue        number(6),
  extras       number(12)   DEFAULT 0,
  constraint sections_pk PRIMARY KEY (section)
);


/**************************************************
*  IMPORTANT NOTE
*  session is an Oracle reserved word,
*  column session changed to session_id
**************************************************/

prompt drop table sessions
drop table sessions;

prompt create table sessions
CREATE TABLE sessions (
  session_id  varchar2(20) DEFAULT '' NOT NULL,
  user_id     number(12)   DEFAULT 1 NOT NULL,
  logintime   date,
  lasttime    date,
  lasttitle   varchar2(50),
  constraint sessions_pk PRIMARY KEY (session_id)
);


/**************************************************
*  IMPORTANT NOTE
*  indexes on time and displaystatus, time created
*  automatically with unique constraint
***************************************************/


prompt drop table stories
drop table stories;

prompt create table stories
CREATE TABLE stories (
  sid           varchar2(20)  DEFAULT '' NOT NULL,
  tid           varchar2(20)  DEFAULT '' NOT NULL,
  user_id       number(12)    DEFAULT 1 NOT NULL,
  title         varchar2(100) DEFAULT '' NOT NULL,
  dept          varchar2(100),
  time          date          DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  introtext     clob,
  bodytext      clob,
  writestatus   number(6)     DEFAULT 0 NOT NULL,
  hits          number(10)    DEFAULT 0 NOT NULL,
  section       varchar2(15)  DEFAULT '' NOT NULL,
  displaystatus number(6)     DEFAULT 0 NOT NULL,
  commentstatus number(6),
  hitparade     varchar2(64)  DEFAULT '0,0,0,0,0,0,0',
  relatedtext   clob,
  extratext     clob,
  constraint stories_pk PRIMARY KEY (sid),
  constraint stories_time_unq UNIQUE (time),
  constraint stories_stat_unq UNIQUE (displaystatus,time)
);


prompt drop table users_param
drop table users_param;

prompt create table users_param
CREATE TABLE users_param (
	param_id     number(12),
        sid          varchar2(20) DEFAULT '' NOT NULL,
	name         varchar2(32) NOT NULL,
	value        clob,
	constraint users_param_unq UNIQUE (sid, name),
	constraint param_id PRIMARY KEY (param_id)
);


prompt drop table storiestuff
drop table storiestuff;

prompt create table storiestuff
CREATE TABLE storiestuff (
  sid        varchar2(20)   DEFAULT '' NOT NULL,
  hits       number(6)      DEFAULT 0 NOT NULL,
  constraint storiesstuff_pk PRIMARY KEY (sid)
);


/*************************************************
*  IMPORTANT NOTE
*  comment is a reserved word
*  column comment changed to submission_comment
**************************************************/

prompt drop table submissions
drop table submissions;

prompt create table submissions
CREATE TABLE submissions (
  subid               varchar2(15)   DEFAULT '' NOT NULL,
  email               varchar2(50),
  name                varchar2(50),
  time                date,
  subj                varchar2(50),
  story               clob,
  tid                 varchar2(20),
  note                varchar2(30),
  section             varchar2(30)   DEFAULT '' NOT NULL,
  submission_comment  varchar2(255),
  user_id             number(12)     DEFAULT 1 NOT NULL,
  ipid			char2(32)     DEFAULT '0.0.0.0' NOT NULL,
  subnetid		char2(32)     DEFAULT '0.0.0.0' NOT NULL,
  del                 number(6)      DEFAULT 0 NOT NULL,
  constraint submissions_pk PRIMARY KEY (subid)
);
CREATE INDEX idx_subid ON submissions(subid,section);
CREATE INDEX idx_ipid ON submissions(ipid,section);
CREATE INDEX idx_subnetid ON submissions(subnetid,section);


prompt drop table templates
drop table templates;

prompt create table templates
CREATE TABLE templates (
	tpid         varchar2(30) DEFAULT '' NOT NULL,
	template     clob,
	seclev       number(12),
	description  clob,
	title        varchar2(128),
	page         varchar2(20) DEFAULT 'misc' NOT NULL,
	constraint templates_pk PRIMARY KEY (tpid)
);
CREATE INDEX idx_tmpltpage ON templates(page);


prompt drop table topics
drop table topics;


prompt create table topics
CREATE TABLE topics (
  tid     varchar2(20) DEFAULT '' NOT NULL,
  image   varchar2(30),
  alttext varchar2(40),
  width   number(12),
  height  number(12),
  constraint topics_pk PRIMARY KEY (tid)
);


prompt drop table tzcodes
drop table tzcodes;

prompt create table tzcodes
CREATE TABLE tzcodes (
  tz           char(3) DEFAULT '' NOT NULL,
  value        number(12),
  description  varchar2(64),
  constraint tzcodes_pk PRIMARY KEY (tz)
);


/**************************************************
* IMPORTANT NOTE
* mode is a reserved word
* column mode chnaged to user_mode
***************************************************/


prompt drop table users
drop table users;


prompt create table users
CREATE TABLE users (
  user_id          number(12),
  nickname         varchar2(20)   DEFAULT '' NOT NULL,
  realemail        varchar2(50)   DEFAULT '' NOT NULL,
  fakeemail        varchar2(75),
  homepage         varchar2(100),
  passwd           varchar2(32)   DEFAULT '' NOT NULL,
  sig              varchar2(160),
  seclev           number(12)     DEFAULT 0 NOT NULL,
  matchname        varchar2(20),
  newpasswd        varchar2(32),
  points           number(12)     DEFAULT 0 NOT NULL,
  posttype         varchar2(10)   DEFAULT 'html' NOT NULL,
  defaultpoints    number(12)     DEFAULT 1 NOT NULL,
  highlightthresh  number(12)     DEFAULT 4 NOT NULL,
  maxcommentsize   number(12)     DEFAULT 4096 NOT NULL,
  hardthresh       number(6)      DEFAULT 0 NOT NULL,
  clbig            number(12)     DEFAULT 0 NOT NULL,
  clsmall          number(12)     DEFAULT 0 NOT NULL,
  reparent         number(12)     DEFAULT 1 NOT NULL,
  nosigs           number(12)     DEFAULT 0 NOT NULL,
  commentlimit     number(12)     DEFAULT 100 NOT NULL,
  commentspill     number(12)     DEFAULT 50 NOT NULL,
  commentsort      number(6)      DEFAULT 0,
  noscores         number(6)      DEFAULT 0 NOT NULL,
  user_mode        varchar2(10)   DEFAULT 'thread',
  threshold        number(6)      DEFAULT 0,
  extid            varchar2(255),
  exaid            varchar2(100),
  exsect           varchar2(100),
  exboxes          varchar2(255),
  maxstories       number(12)     DEFAULT 30 NOT NULL,
  noboxes          number(6)      DEFAULT 0 NOT NULL,
  totalmods        number(12)     DEFAULT 0 NOT NULL,
  realname         varchar2(50),
  bio              clob,
  tokens           number(12)     DEFAULT 0 NOT NULL,
  lastgranted      date           DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  karma            number(12)     DEFAULT 0 NOT NULL,
  maillist         number(6)      DEFAULT 0 NOT NULL,
  totalcomments    number(6)      DEFAULT 0,
  lastmm           date           DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  lastaccess       date           DEFAULT trunc(to_date('1970-01-01', 'YYYY-MM-DD')) NOT NULL,
  lastmmid         number(12)     DEFAULT 0 NOT NULL,
  session_login    number(6)      DEFAULT 0 NOT NULL,
  willing          number(6)      DEFAULT 1 NOT NULL,
  dfid             number(12)     DEFAULT 0 NOT NULL,
  tzcode           char(3)        DEFAULT 'edt' NOT NULL,
  noicons          number(6)      DEFAULT 0 NOT NULL,
  light            number(6)      DEFAULT 0 NOT NULL,
  mylinks          varchar2(255)  DEFAULT '' NOT NULL,
  constraint users_pk PRIMARY KEY (user_id)
);
CREATE INDEX idx_login ON users(user_id,passwd,nickname);
CREATE INDEX idx_chk4user ON users(nickname,realemail);
CREATE INDEX idx_chk4email ON users(realemail);

prompt drop sequence users_seq
drop sequence users_seq;

prompt create sequence users_seq
create sequence users_seq
      start with 1;



prompt drop table users_param
drop table users_param;

prompt create table users_param
CREATE TABLE users_param (
	param_id       number(12),
	user_id        number(12)   DEFAULT 1 NOT NULL,
	name           varchar2(32) NOT NULL,
	value          clob,
	constraint users_param_unq UNIQUE (user_id, name),
        constraint users_param_pk PRIMARY KEY (param_id)
);



prompt drop table vars
drop table vars;


prompt create table vars
CREATE TABLE vars (
  name          varchar2(32) DEFAULT '' NOT NULL,
  value         clob,
  description   varchar2(127),
  constraint vars_pk PRIMARY KEY (name)
);


spool off
