# MySQL dump 6.0
#
# Host: localhost    Database: slashclean
#--------------------------------------------------------
# Server version	3.22.25-log

#
# Table structure for table 'accesslog'
#
CREATE TABLE accesslog (
  id int(5) DEFAULT '0' NOT NULL auto_increment,
  host_addr varchar(16) DEFAULT '' NOT NULL,
  op varchar(8),
  dat varchar(32),
  uid int(1) DEFAULT '-1' NOT NULL,
  ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  query_string varchar(50),
  user_agent varchar(50),
  PRIMARY KEY (id)
);

#
# Table structure for table 'authors'
#
CREATE TABLE authors (
  aid char(30) DEFAULT '' NOT NULL,
  name char(50),
  url char(50),
  email char(50),
  quote char(50),
  copy char(255),
  pwd char(8),
  seclev int(11),
  lasttitle char(20),
  section char(20),
  deletedsubmissions int(11) DEFAULT '0',
  matchname char(30),
  PRIMARY KEY (aid)
);

#
# Table structure for table 'blocks'
#
CREATE TABLE blocks (
  bid varchar(30) DEFAULT '' NOT NULL,
  block text,
  aid varchar(20),
  seclev int(1),
  type varchar(20) DEFAULT '' NOT NULL,
  description text,
  blockbak text,
  PRIMARY KEY (bid),
  KEY type (type)
);

#
# Table structure for table 'commentcodes'
#
CREATE TABLE commentcodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'formkeys'
#
CREATE TABLE formkeys (
  formkey varchar(20) DEFAULT '' NOT NULL,
  formname varchar(20) DEFAULT '' NOT NULL,
  id varchar(20) DEFAULT '' NOT NULL,
  sid varchar(30) DEFAULT '' NOT NULL,
  uid int(1) DEFAULT '-1' NOT NULL,
  host_name varchar(30) DEFAULT '0.0.0.0' NOT NULL,
  value int(1) DEFAULT '0' NOT NULL,
  cid int(15) DEFAULT '0' NOT NULL,
  comment_length int(4) DEFAULT '0' NOT NULL,
  ts int(12) DEFAULT '0' NOT NULL,
  submit_ts int(12) DEFAULT '0' NOT NULL,
  PRIMARY KEY (formkey),
  KEY formname (formname),
  KEY id (id),
  KEY ts (ts),
  KEY submit_ts (submit_ts)
);

#
# Table structure for table 'commentmodes'
#
CREATE TABLE commentmodes (
  mode varchar(16) DEFAULT '' NOT NULL,
  name varchar(32),
  description varchar(64),
  PRIMARY KEY (mode)
);

#
# Table structure for table 'comments'
#
CREATE TABLE comments (
  sid varchar(30) DEFAULT '' NOT NULL,
  cid int(15) DEFAULT '0' NOT NULL,
  pid int(15) DEFAULT '0' NOT NULL,
  date datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  host_name varchar(30) DEFAULT '0.0.0.0' NOT NULL,
  subject varchar(50) DEFAULT '' NOT NULL,
  comment text NOT NULL,
  uid int(1) DEFAULT '-1' NOT NULL,
  points int(1) DEFAULT '0' NOT NULL,
  lastmod int(1) DEFAULT '-1',
  reason int(11) DEFAULT '0',
  PRIMARY KEY (sid,cid),
  KEY display (sid,points,uid),
  KEY byname (uid,points),
  KEY theusual (sid,uid,points,cid),
  KEY countreplies (sid,pid)
);

#
# Table structure for table 'content_filters'
#
CREATE TABLE content_filters (
  filter_id int(4) DEFAULT '0' NOT NULL auto_increment,
  regex varchar(100) DEFAULT '' NOT NULL,
  modifier varchar(5) DEFAULT '' NOT NULL,
  field varchar(20) DEFAULT '' NOT NULL,
  ratio float(6,4) DEFAULT '0.0000' NOT NULL,
  minimum_match int(6) DEFAULT '0' NOT NULL,
  minimum_length int(10) DEFAULT '0' NOT NULL,
  err_message varchar(150) DEFAULT '',
  maximum_length int(10) DEFAULT '0' NOT NULL,
  PRIMARY KEY (filter_id),
  KEY regex (regex),
  KEY field (field)
);

#
# Table structure for table 'dateformats'
#
CREATE TABLE dateformats (
  id int(1) DEFAULT '0' NOT NULL,
  format varchar(32),
  description varchar(64),
  PRIMARY KEY (id)
);

#
# Table structure for table 'discussions'
#
CREATE TABLE discussions (
  sid varchar(20) DEFAULT '' NOT NULL,
  title varchar(128),
  url varchar(128),
  ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  PRIMARY KEY (sid)
);

#
# Table structure for table 'displaycodes'
#
CREATE TABLE displaycodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'hitters'
#
CREATE TABLE hitters (
  id int(5) DEFAULT '0' NOT NULL auto_increment,
  host_addr varchar(15) DEFAULT '' NOT NULL,
  hits int(6) DEFAULT '0' NOT NULL,
  PRIMARY KEY (id),
  KEY host_addr (host_addr),
  KEY hits (hits)
);

#
# Table structure for table 'isolatemodes'
#
CREATE TABLE isolatemodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'issuemodes'
#
CREATE TABLE issuemodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'maillist'
#
CREATE TABLE maillist (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'metamodlog'
#
CREATE TABLE metamodlog (
  mmid int(11) DEFAULT '0' NOT NULL,
  uid int(11) DEFAULT '0' NOT NULL,
  val int(11) DEFAULT '0' NOT NULL,
  ts datetime,
  id int(11) DEFAULT '0' NOT NULL auto_increment,
  PRIMARY KEY (id)
);

#
# Table structure for table 'moderatorlog'
#
CREATE TABLE moderatorlog (
  id int(1) DEFAULT '0' NOT NULL auto_increment,
  uid int(1) DEFAULT '0' NOT NULL,
  val int(1) DEFAULT '0' NOT NULL,
  sid varchar(30) DEFAULT '' NOT NULL,
  ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  cid int(1) DEFAULT '0' NOT NULL,
  reason int(11) DEFAULT '0',
  PRIMARY KEY (id),
  KEY sid (sid,cid),
  KEY sid_2 (sid,uid,cid)
);

#
# Table structure for table 'newstories'
#
CREATE TABLE newstories (
  sid varchar(20) DEFAULT '' NOT NULL,
  tid varchar(20) DEFAULT '' NOT NULL,
  aid varchar(30) DEFAULT '' NOT NULL,
  commentcount int(1) DEFAULT '0',
  title varchar(100) DEFAULT '' NOT NULL,
  dept varchar(100),
  time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  introtext text,
  bodytext text,
  writestatus int(1) DEFAULT '0' NOT NULL,
  hits int(1) DEFAULT '0' NOT NULL,
  section varchar(15) DEFAULT '' NOT NULL,
  displaystatus int(1) DEFAULT '0' NOT NULL,
  commentstatus int(1),
  hitparade varchar(64) DEFAULT '0,0,0,0,0,0,0',
  relatedtext text,
  extratext text,
  PRIMARY KEY (sid),
  KEY time (time),
  KEY searchform (displaystatus,time)
);

#
# Table structure for table 'pollanswers'
#
CREATE TABLE pollanswers (
  qid char(20) DEFAULT '' NOT NULL,
  aid int(11) DEFAULT '0' NOT NULL,
  answer char(255),
  votes int(11),
  PRIMARY KEY (qid,aid)
);

#
# Table structure for table 'pollquestions'
#
CREATE TABLE pollquestions (
  qid char(20) DEFAULT '' NOT NULL,
  question char(255) DEFAULT '' NOT NULL,
  voters int(11),
  date datetime,
  PRIMARY KEY (qid)
);

#
# Table structure for table 'pollvoters'
#
CREATE TABLE pollvoters (
  qid char(20) DEFAULT '' NOT NULL,
  id char(35) DEFAULT '' NOT NULL,
  time datetime,
  uid int(11) DEFAULT '-1' NOT NULL,
  KEY qid (qid,id,uid)
);

#
# Table structure for table 'postmodes'
#
CREATE TABLE postmodes (
  code char(10) DEFAULT '' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'sectionblocks'
#
CREATE TABLE sectionblocks (
  section varchar(30) DEFAULT '' NOT NULL,
  bid varchar(30) DEFAULT '' NOT NULL,
  ordernum tinyint(4) DEFAULT '0' NOT NULL,
  title varchar(128),
  portal tinyint(4) DEFAULT '0' NOT NULL,
  url varchar(128),
  rdf varchar(255),
  retrieve int(1),
  PRIMARY KEY (bid),
  KEY bididx (bid),
  KEY normalblocks (bid,portal,ordernum),
  KEY normalsection (section,bid,portal,ordernum)
);

#
# Table structure for table 'sections'
#
CREATE TABLE sections (
  section varchar(30) DEFAULT '' NOT NULL,
  artcount int(11),
  title varchar(64),
  qid varchar(20) DEFAULT '' NOT NULL,
  isolate int(1),
  issue int(1),
  extras int(11) DEFAULT '0',
  PRIMARY KEY (section)
);

#
# Table structure for table 'sessions'
#
CREATE TABLE sessions (
  session varchar(20) DEFAULT '' NOT NULL,
  aid varchar(30),
  logintime datetime,
  lasttime datetime,
  lasttitle varchar(50),
  PRIMARY KEY (session)
);

#
# Table structure for table 'slashslices'
#
CREATE TABLE slashslices (
  ssID int(11) DEFAULT '0' NOT NULL auto_increment,
  ssRank int(11) DEFAULT '0' NOT NULL,
  ssRUID int(11),
  ssLayer text,
  PRIMARY KEY (ssID,ssRank),
  KEY rank (ssRank)
);

#
# Table structure for table 'sortcodes'
#
CREATE TABLE sortcodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'statuscodes'
#
CREATE TABLE statuscodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Table structure for table 'stories'
#
CREATE TABLE stories (
  sid varchar(20) DEFAULT '' NOT NULL,
  tid varchar(20) DEFAULT '' NOT NULL,
  aid varchar(30) DEFAULT '' NOT NULL,
  commentcount int(1) DEFAULT '0',
  title varchar(100) DEFAULT '' NOT NULL,
  dept varchar(100),
  time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  introtext text,
  bodytext text,
  writestatus int(1) DEFAULT '0' NOT NULL,
  hits int(1) DEFAULT '0' NOT NULL,
  section varchar(15) DEFAULT '' NOT NULL,
  displaystatus int(1) DEFAULT '0' NOT NULL,
  commentstatus int(1),
  hitparade varchar(64) DEFAULT '0,0,0,0,0,0,0',
  relatedtext text,
  extratext text,
  PRIMARY KEY (sid),
  KEY time (time),
  KEY searchform (displaystatus,time)
);

#
# Table structure for table 'storiestuff'
#
CREATE TABLE storiestuff (
  sid varchar(20) DEFAULT '' NOT NULL,
  hits int(1) DEFAULT '0' NOT NULL,
  PRIMARY KEY (sid)
);

#
# Table structure for table 'submissions'
#
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
  uid int(11) DEFAULT '-1' NOT NULL,
  del tinyint(4) DEFAULT '0' NOT NULL,
  PRIMARY KEY (subid),
  KEY subid (subid,section)
);

#
# Table structure for table 'threshcodes'
#
CREATE TABLE threshcodes (
  thresh int(1) DEFAULT '0' NOT NULL,
  description char(64),
  PRIMARY KEY (thresh)
);

#
# Table structure for table 'topics'
#
CREATE TABLE topics (
  tid char(20) DEFAULT '' NOT NULL,
  image char(30),
  alttext char(40),
  width int(11),
  height int(11),
  PRIMARY KEY (tid)
);

#
# Table structure for table 'tzcodes'
#
CREATE TABLE tzcodes (
  tz char(3) DEFAULT '' NOT NULL,
  offset int(1),
  description varchar(64),
  PRIMARY KEY (tz)
);

#
# Table structure for table 'users'
#
CREATE TABLE users (
  uid int(11) DEFAULT '0' NOT NULL auto_increment,
  nickname varchar(20) DEFAULT '' NOT NULL,
  realemail varchar(50) DEFAULT '' NOT NULL,
  fakeemail varchar(50),
  homepage varchar(100),
  passwd varchar(12) DEFAULT '' NOT NULL,
  sig varchar(160),
  seclev int(11) DEFAULT '0' NOT NULL,
  matchname varchar(20),
  PRIMARY KEY (uid),
  KEY login (uid,passwd,nickname),
  KEY chk4user (nickname,realemail),
  KEY chk4email (realemail)
);

#
# Table structure for table 'users_comments'
#
CREATE TABLE users_comments (
  uid int(11) DEFAULT '0' NOT NULL,
  points int(11) DEFAULT '0' NOT NULL,
  posttype varchar(10) DEFAULT 'html' NOT NULL,
  defaultpoints int(11) DEFAULT '1' NOT NULL,
  highlightthresh int(11) DEFAULT '4' NOT NULL,
  maxcommentsize int(11) DEFAULT '4096' NOT NULL,
  hardthresh tinyint(4) DEFAULT '0' NOT NULL,
  clbig int(11) DEFAULT '0' NOT NULL,
  clsmall int(11) DEFAULT '0' NOT NULL,
  reparent tinyint(4) DEFAULT '1' NOT NULL,
  nosigs tinyint(4) DEFAULT '0' NOT NULL,
  commentlimit int(11) DEFAULT '100' NOT NULL,
  commentspill int(11) DEFAULT '50' NOT NULL,
  commentsort int(1) DEFAULT '0',
  noscores tinyint(4) DEFAULT '0' NOT NULL,
  mode varchar(10) DEFAULT 'thread',
  threshold int(1) DEFAULT '0',
  PRIMARY KEY (uid)
);

#
# Table structure for table 'users_index'
#
CREATE TABLE users_index (
  uid int(11) DEFAULT '0' NOT NULL,
  extid varchar(255),
  exaid varchar(100),
  exsect varchar(100),
  exboxes varchar(255),
  maxstories int(11) DEFAULT '30' NOT NULL,
  noboxes tinyint(4) DEFAULT '0' NOT NULL,
  PRIMARY KEY (uid)
);

#
# Table structure for table 'users_info'
#
CREATE TABLE users_info (
  uid int(11) DEFAULT '0' NOT NULL,
  totalmods int(11) DEFAULT '0' NOT NULL,
  realname varchar(50),
  bio text,
  tokens int(11) DEFAULT '0' NOT NULL,
  lastgranted date DEFAULT '0000-00-00' NOT NULL,
  karma int(11) DEFAULT '0' NOT NULL,
  maillist tinyint(4) DEFAULT '0' NOT NULL,
  totalcomments int(1) DEFAULT '0',
  lastmm date DEFAULT '0000-00-00' NOT NULL,
  lastaccess date DEFAULT '0000-00-00' NOT NULL,
  lastmmid int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (uid)
);

#
# Table structure for table 'users_key'
#
CREATE TABLE users_key (
  uid int(11) DEFAULT '0' NOT NULL,
  pubkey text,
  PRIMARY KEY (uid)
);

#
# Table structure for table 'users_prefs'
#
CREATE TABLE users_prefs (
  uid int(11) DEFAULT '0' NOT NULL,
  willing tinyint(4) DEFAULT '1' NOT NULL,
  dfid int(11) DEFAULT '0' NOT NULL,
  tzcode char(3) DEFAULT 'edt' NOT NULL,
  noicons tinyint(4) DEFAULT '0' NOT NULL,
  light tinyint(4) DEFAULT '0' NOT NULL,
  mylinks varchar(255) DEFAULT '' NOT NULL,
  PRIMARY KEY (uid)
);

#
# Table structure for table 'vars'
#
CREATE TABLE vars (
  name char(32) DEFAULT '' NOT NULL,
  value char(127),
  description char(127),
  PRIMARY KEY (name)
);

