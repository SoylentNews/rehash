# Slashcode schema creation script for Oracle 8.x
# Stephen Clouse <thebrain@warpcore.org>
#
# Based off sql/mysql/slashschema_create.sql, rev 1.4
#
# Summary of changes from original MySQL script:
#   - Since Oracle still treats '' as NULL (in violation of SQL-92),
#     all DEFAULT '' clauses have been removed since they are pretty
#     much worthless
#   - A few NOT NULL constraints were removed since they didnt really
#     seem to be necessary:
#       - content_filters.modifier
#   - Some VARCHAR fields have had their max lengths extended to
#     avoid ORA-01401 (inserted value too large for column) errors;
#     MySQL silently truncates the value so it doesn''t error out
#   - Several field names conflict with Oracle reserved words.  These
#     fields and their new names are:
#       - *(uid) => user_id
#       - *(comment) => comment_text
#       - *(mode) => comment_mode
#       - comments(date) => comment_date
#       - pollquestions(date) => poll_date
#       - sessions(session) => session_id
#   - MySQL-specific datatypes converted to Oracle datatypes, or
#     datatypes with differences in implementation changed to avoid
#     heavy internal reworking:
#       - CHAR(*) => VARCHAR2(*) (because Oracle right pads CHARs)
#       - INT(*) => NUMBER(38)
#       - TINYINT(*) => NUMBER(3)
#       - VARCHAR(*) => VARCHAR2(*)
#       - TIMEDATE => DATE
#       - TEXT => VARCHAR2(4000) or CLOB
#   - Everything has been given a nice descriptive name, including
#     constraints
#   - UNIQUE constraints in Oracle automatically create an index to
#     manage the constraint, so KEY declarations that were the same
#     as a UNIQUE constraint were thrown out (normally they would be
#     turned into a CREATE INDEX statement)
#   - Auto-increment fields are effectively simulated using a BEFORE
#     INSERT trigger
#
# Note that the Oracle user you set up for slash needs the following
# privileges:
#      CREATE SESSION
#      CREATE TABLE
#      CREATE SEQUENCE
#      CREATE OR REPLACE TRIGGER
#
# This has been tested on Oracle 8.1.6.  It should work with any 8.x
# version but no guarantees are offered.  I highly doubt it will work
# with pre-8 versions.



DROP TABLE abusers;
CREATE TABLE abusers (
	abuser_id	NUMBER(38)					CONSTRAINT pk_abusers PRIMARY KEY,
	host_name	VARCHAR2(25)					CONSTRAINT nn_abusers_host_name NOT NULL,
	pagename	VARCHAR2(20)					CONSTRAINT nn_abusers_pagename NOT NULL,
	ts		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_abusers_ts NOT NULL,
	reason		VARCHAR2(120)					CONSTRAINT nn_abusers_reason NOT NULL,
	querystring	VARCHAR2(60)					CONSTRAINT nn_abusers_querystring NOT NULL
);
CREATE INDEX idx_abusers_host_name ON abusers (host_name);
CREATE INDEX idx_abusers_reason ON abusers (reason);
DROP SEQUENCE seq_abusers;
CREATE SEQUENCE seq_abusers START WITH 1;
CREATE OR REPLACE TRIGGER trg_abusers_auto_inc BEFORE INSERT ON abusers FOR EACH ROW
BEGIN
IF (:new.abuser_id IS NULL OR :new.abuser_id = 0) THEN
	SELECT seq_abusers.nextval INTO :new.abuser_id FROM DUAL;
END IF;
END;



DROP TABLE accesslog;
CREATE TABLE accesslog (
	id		NUMBER(38)					CONSTRAINT pk_accesslog PRIMARY KEY,
	host_addr	VARCHAR2(16)					CONSTRAINT nn_accesslog_host_addr NOT NULL,
	op		VARCHAR2(32),
	dat		VARCHAR2(64),
	user_id		NUMBER(38)					CONSTRAINT nn_accesslog_user_id NOT NULL,
	ts		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_accesslog_ts NOT NULL,
	query_string	VARCHAR2(2048),
	user_agent	VARCHAR2(512)
);
DROP SEQUENCE seq_accesslog;
CREATE SEQUENCE seq_accesslog START WITH 1;
CREATE OR REPLACE TRIGGER trg_accesslog_auto_inc BEFORE INSERT ON accesslog FOR EACH ROW
BEGIN
IF (:new.id IS NULL OR :new.id = 0) THEN
	SELECT seq_accesslog.nextval INTO :new.id FROM DUAL;
END IF;
END;



DROP TABLE backup_blocks;
CREATE TABLE backup_blocks (
	bid		VARCHAR2(30)					CONSTRAINT pk_backup_blocks PRIMARY KEY,
	block		VARCHAR2(4000)
);



DROP TABLE blocks;
CREATE TABLE blocks (
	bid		VARCHAR2(30)					CONSTRAINT pk_blocks PRIMARY KEY,
	block		VARCHAR2(4000),
	seclev		NUMBER(38),
	type		VARCHAR2(20)					CONSTRAINT nn_blocks_type NOT NULL,
	description	VARCHAR2(4000),
	section		VARCHAR2(30)					CONSTRAINT nn_blocks_section NOT NULL,
	ordernum	NUMBER(3)	DEFAULT 0,
	title		VARCHAR2(128),
	portal		NUMBER(3)	DEFAULT 0,
	url		VARCHAR2(128),
	rdf		VARCHAR2(255),
	retrieve	NUMBER(38)	DEFAULT 0
);
CREATE INDEX idx_blocks_type ON blocks (type);
CREATE INDEX idx_blocks_section ON blocks (section);



DROP TABLE code_param;
CREATE TABLE code_param (
	param_id	NUMBER(38)					CONSTRAINT pk_code_param PRIMARY KEY,
	type		VARCHAR2(16)					CONSTRAINT nn_code_param_type NOT NULL,
	code		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_code_param_code NOT NULL,
	name		VARCHAR2(32),
	CONSTRAINT	un_code_param_code_key				UNIQUE (type,code)
);
DROP SEQUENCE seq_code_param;
CREATE SEQUENCE seq_code_param START WITH 1;
CREATE OR REPLACE TRIGGER trg_code_param_auto_inc BEFORE INSERT ON code_param FOR EACH ROW
BEGIN
IF (:new.param_id IS NULL OR :new.param_id = 0) THEN
	SELECT seq_code_param.nextval INTO :new.param_id FROM DUAL;
END IF;
END;



DROP TABLE commentmodes;
CREATE TABLE commentmodes (
	comment_mode	VARCHAR2(16)					CONSTRAINT pk_commentmodes PRIMARY KEY,
	name		VARCHAR2(32),
	description	VARCHAR2(64)
);



DROP TABLE comments;
CREATE TABLE comments (
	sid		VARCHAR2(16),
	cid		NUMBER(38)	DEFAULT 0,
	pid		NUMBER(38)	DEFAULT 0,
	comment_date	DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_comments_date NOT NULL,
	host_name	VARCHAR2(30)	DEFAULT '0.0.0.0'		CONSTRAINT nn_comments_host_name NOT NULL,
	subject		VARCHAR2(50)					CONSTRAINT nn_comments_subject NOT NULL,
	comment_text	CLOB						CONSTRAINT nn_comments_comment NOT NULL,
	user_id		NUMBER(38)					CONSTRAINT nn_comments_user_id NOT NULL,
	points		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_comments_points NOT NULL,
	lastmod		NUMBER(38),
	reason		NUMBER(38)	DEFAULT 0,
	CONSTRAINT	pk_comments					PRIMARY KEY (sid, cid)
);
CREATE INDEX idx_comments_display ON comments (sid, points, user_id);
CREATE INDEX idx_comments_byname ON comments (user_id, points);
CREATE INDEX idx_comments_theusual ON comments (sid, user_id, points, cid);
CREATE INDEX idx_comments_countreplies ON comments (sid, pid);



DROP TABLE content_filters;
CREATE TABLE content_filters (
	filter_id	NUMBER(38)					CONSTRAINT pk_content_filters PRIMARY KEY,
	regex		VARCHAR2(100)					CONSTRAINT nn_content_filters_regex NOT NULL,
	modifier	VARCHAR2(5),
	field		VARCHAR2(20)					CONSTRAINT nn_content_filters_field NOT NULL,
	ratio		NUMBER(38,4)	DEFAULT 0			CONSTRAINT nn_content_filters_ratio NOT NULL,
	minimum_match	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_content_filters_min_match NOT NULL,
	minimum_length	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_content_filters_min_length NOT NULL,
	err_message	VARCHAR2(150),
	maximum_length	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_content_filters_max_length NOT NULL
);
CREATE INDEX idx_content_filters_regex ON content_filters (regex);
CREATE INDEX idx_content_filters_field_key ON content_filters (field);
DROP SEQUENCE seq_content_filters;
CREATE SEQUENCE seq_content_filters START WITH 1;
CREATE OR REPLACE TRIGGER trg_content_filters_auto_inc BEFORE INSERT ON content_filters FOR EACH ROW
BEGIN
IF (:new.filter_id IS NULL OR :new.filter_id = 0) THEN
	SELECT seq_content_filters.nextval INTO :new.filter_id FROM DUAL;
END IF;
END;



DROP TABLE dateformats;
CREATE TABLE dateformats (
	id		NUMBER(38)					CONSTRAINT pk_dateformats PRIMARY KEY,
	format		VARCHAR2(32),
	description	VARCHAR2(64)
);



DROP TABLE discussions;
CREATE TABLE discussions (
	sid		VARCHAR2(16)					CONSTRAINT pk_discussions PRIMARY KEY,
	title		VARCHAR2(128),
	url		VARCHAR2(128),
	ts		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_discussions_ts NOT NULL
);



DROP TABLE formkeys;
CREATE TABLE formkeys (
	formkey		VARCHAR2(20)					CONSTRAINT pk_formkeys PRIMARY KEY,
	formname	VARCHAR2(20)					CONSTRAINT nn_formkeys_formname NOT NULL,
	id		VARCHAR2(30)					CONSTRAINT nn_formkeys_id NOT NULL,
	sid		VARCHAR2(16)					CONSTRAINT nn_formkeys_sid NOT NULL,
	user_id		NUMBER(38)					CONSTRAINT nn_formkeys_user_id NOT NULL,
	host_name	VARCHAR2(30)	DEFAULT '0.0.0.0'		CONSTRAINT nn_formkeys_host_name NOT NULL,
	value		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_formkeys_value NOT NULL,
	cid		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_formkeys_cid NOT NULL,
	ts		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_formkeys_ts NOT NULL,
	submit_ts	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_formkeys_submit_ts NOT NULL,
	content_length	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_formkeys_content_length NOT NULL
);
CREATE INDEX idx_formkeys_formname ON formkeys (formname);
CREATE INDEX idx_formkeys_id ON formkeys (id);
CREATE INDEX idx_formkeys_ts ON formkeys (ts);
CREATE INDEX idx_formkeys_submit_ts ON formkeys (submit_ts);



DROP TABLE site_info;
CREATE TABLE site_info (
	param_id	NUMBER(38)					CONSTRAINT pk_site_info PRIMARY KEY,
	name		VARCHAR2(50)					CONSTRAINT nn_site_info_name NOT NULL,
	value		VARCHAR2(200)					CONSTRAINT nn_site_info_value NOT NULL,
	description	VARCHAR2(255),
	CONSTRAINT	un_site_info_site_keys				UNIQUE (name,value)
);
DROP SEQUENCE seq_site_info;
CREATE SEQUENCE seq_site_info START WITH 1;
CREATE OR REPLACE TRIGGER trg_site_info_auto_inc BEFORE INSERT ON site_info FOR EACH ROW
BEGIN
IF (:new.param_id IS NULL OR :new.param_id = 0) THEN
	SELECT seq_site_info.nextval INTO :new.param_id FROM DUAL;
END IF;
END;



DROP TABLE menus;
CREATE TABLE menus (
	id		NUMBER(38)					CONSTRAINT pk_menus PRIMARY KEY,
	menu		VARCHAR2(20)					CONSTRAINT nn_menus_menu NOT NULL,
	label		VARCHAR2(200)					CONSTRAINT nn_menus_label NOT NULL,
	value		VARCHAR2(4000),
	seclev		NUMBER(38),
	menuorder	NUMBER(38),
	CONSTRAINT	un_menus_page_labels				UNIQUE (menu,label)
);
DROP SEQUENCE seq_menus;
CREATE SEQUENCE seq_menus START WITH 1;
CREATE OR REPLACE TRIGGER trg_menus_auto_inc BEFORE INSERT ON menus FOR EACH ROW
BEGIN
IF (:new.id IS NULL OR :new.id = 0) THEN
	SELECT seq_menus.nextval INTO :new.id FROM DUAL;
END IF;
END;



DROP TABLE metamodlog;
CREATE TABLE metamodlog (
	mmid		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_metamodlog_mmid NOT NULL,
	user_id		NUMBER(38)					CONSTRAINT nn_metamodlog_user_id NOT NULL,
	val		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_metamodlog_val NOT NULL,
	ts		DATE,
	id		NUMBER(38)					CONSTRAINT pk_metamodlog PRIMARY KEY,
	flag		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_metamodlog_flag NOT NULL
);
DROP SEQUENCE seq_metamodlog;
CREATE SEQUENCE seq_metamodlog START WITH 1;
CREATE OR REPLACE TRIGGER trg_metamodlog_auto_inc BEFORE INSERT ON metamodlog FOR EACH ROW
BEGIN
IF (:new.id IS NULL OR :new.id = 0) THEN
	SELECT seq_metamodlog.nextval INTO :new.id FROM DUAL;
END IF;
END;



DROP TABLE moderatorlog;
CREATE TABLE moderatorlog (
	id		NUMBER(38)					CONSTRAINT pk_moderatorlog PRIMARY KEY,
	user_id		NUMBER(38)					CONSTRAINT nn_moderatorlog_user_id NOT NULL,
	val		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_moderatorlog_val NOT NULL,
	sid		VARCHAR2(16)					CONSTRAINT nn_moderatorlog_sid NOT NULL,
	ts		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_moderatorlog_ts NOT NULL,
	cid		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_moderatorlog_cid NOT NULL,
	reason		NUMBER(38)	DEFAULT 0,
	active		NUMBER(38)	DEFAULT 1			CONSTRAINT nn_moderatorlog_active NOT NULL
);
CREATE INDEX idx_moderatorlog_sid ON moderatorlog (sid, cid);
CREATE INDEX idx_moderatorlog_sid_2 ON moderatorlog (sid, user_id, cid);
DROP SEQUENCE seq_moderatorlog;
CREATE SEQUENCE seq_moderatorlog START WITH 1;
CREATE OR REPLACE TRIGGER trg_moderatorlog_auto_inc BEFORE INSERT ON moderatorlog FOR EACH ROW
BEGIN
IF (:new.id IS NULL OR :new.id = 0) THEN
	SELECT seq_moderatorlog.nextval INTO :new.id FROM DUAL;
END IF;
END;



DROP TABLE newstories;
CREATE TABLE newstories (
	sid		VARCHAR2(16)					CONSTRAINT pk_newstories PRIMARY KEY,
	tid		VARCHAR2(20)					CONSTRAINT nn_newstories_tid NOT NULL,
	user_id		NUMBER(38)					CONSTRAINT nn_newstories_user_id NOT NULL,
	commentcount	NUMBER(38)	DEFAULT 0,
	title		VARCHAR2(100)					CONSTRAINT nn_newstories_title NOT NULL,
	dept		VARCHAR2(100),
	time		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_newstories_time NOT NULL,
	introtext	CLOB,
	bodytext	CLOB,
	writestatus	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_newstories_writestatus NOT NULL,
	hits		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_newstories_hits NOT NULL,
	section		VARCHAR2(30)					CONSTRAINT nn_newstories_section NOT NULL,
	displaystatus	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_newstories_displaystatus NOT NULL,
	commentstatus	NUMBER(38),
	hitparade	VARCHAR2(64)	DEFAULT '0,0,0,0,0,0,0',
	relatedtext	CLOB,
	extratext	CLOB
);
CREATE INDEX idx_newstories_time ON newstories (time);
CREATE INDEX idx_newstories_searchform ON newstories (displaystatus, time);



DROP TABLE pollanswers;
CREATE TABLE pollanswers (
	qid		VARCHAR2(20),
	aid		NUMBER(38)	DEFAULT 0,
	answer		VARCHAR2(255),
	votes		NUMBER(38),
	CONSTRAINT	pk_pollanswers					PRIMARY KEY (qid, aid)
);



DROP TABLE pollquestions;
CREATE TABLE pollquestions (
	qid		VARCHAR2(20)					CONSTRAINT pk_pollquestions PRIMARY KEY,
	question	VARCHAR2(255)					CONSTRAINT nn_pollquestions_question NOT NULL,
	voters		NUMBER(38),
	poll_date	DATE
);



DROP TABLE pollvoters;
CREATE TABLE pollvoters (
	qid		VARCHAR2(20)					CONSTRAINT nn_pollvoters_qid NOT NULL,
	id		VARCHAR2(35)					CONSTRAINT nn_pollvoters_id NOT NULL,
	time		DATE,
	user_id		NUMBER(38)					CONSTRAINT nn_pollvoters_user_id NOT NULL
);
CREATE INDEX idx_pollvoters_qid ON pollvoters (qid, id, user_id);



DROP TABLE sections;
CREATE TABLE sections (
	section		VARCHAR2(30)					CONSTRAINT pk_sections PRIMARY KEY,
	artcount	NUMBER(38),
	title		VARCHAR2(64),
	qid		VARCHAR2(20)					CONSTRAINT nn_sections_qid NOT NULL,
	isolate		NUMBER(38),
	issue		NUMBER(38),
	extras		NUMBER(38)	DEFAULT 0
);



DROP TABLE sessions;
CREATE TABLE sessions (
	session_id	NUMBER(38)					CONSTRAINT pk_sessions PRIMARY KEY,
	user_id		NUMBER(38),
	logintime	DATE,
	lasttime	DATE,
	lasttitle	VARCHAR2(50)
);
DROP SEQUENCE seq_sessions;
CREATE SEQUENCE seq_sessions START WITH 1;
CREATE OR REPLACE TRIGGER trg_sessions_auto_inc BEFORE INSERT ON sessions FOR EACH ROW
BEGIN
IF (:new.session_id IS NULL OR :new.session_id = 0) THEN
	SELECT seq_sessions.nextval INTO :new.session_id FROM DUAL;
END IF;
END;



DROP TABLE stories;
CREATE TABLE stories (
	sid		VARCHAR2(16)					CONSTRAINT pk_stories PRIMARY KEY,
	tid		VARCHAR2(20)					CONSTRAINT nn_stories_tid NOT NULL,
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT nn_stories_user_id NOT NULL,
	commentcount	NUMBER(38)	DEFAULT 0,
	title		VARCHAR2(100)					CONSTRAINT nn_stories_title NOT NULL,
	dept		VARCHAR2(100),
	time		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_stories_time NOT NULL,
	introtext	CLOB,
	bodytext	CLOB,
	writestatus	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_stories_writestatus NOT NULL,
	hits		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_stories_hits NOT NULL,
	section		VARCHAR2(30)					CONSTRAINT nn_stories_section NOT NULL,
	displaystatus	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_stories_displaystatus NOT NULL,
	commentstatus	NUMBER(38),
	hitparade	VARCHAR2(64)	DEFAULT '0,0,0,0,0,0,0',
	relatedtext	CLOB,
	extratext	CLOB
);
CREATE INDEX idx_stories_time ON stories (time);
CREATE INDEX idx_stories_searchform ON stories (displaystatus, time);



DROP TABLE story_param;
CREATE TABLE story_param (
	param_id	NUMBER(38)					CONSTRAINT pk_story_param PRIMARY KEY,
	sid		VARCHAR2(16)					CONSTRAINT nn_story_param_sid NOT NULL,
	name		VARCHAR2(32)					CONSTRAINT nn_story_param_name NOT NULL,
	value		VARCHAR2(254)					CONSTRAINT nn_story_param_value NOT NULL,
	CONSTRAINT	un_story_param_story_key			UNIQUE (sid, name)
);
DROP SEQUENCE seq_story_param;
CREATE SEQUENCE seq_story_param START WITH 1;
CREATE OR REPLACE TRIGGER trg_story_param_auto_inc BEFORE INSERT ON story_param FOR EACH ROW
BEGIN
IF (:new.param_id IS NULL OR :new.param_id = 0) THEN
	SELECT seq_story_param.nextval INTO :new.param_id FROM DUAL;
END IF;
END;



DROP TABLE storiestuff;
CREATE TABLE storiestuff (
	sid		VARCHAR2(16)					CONSTRAINT pk_storiestuff PRIMARY KEY,
	hits		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_storiestuff_hits NOT NULL
);



DROP TABLE submissions;
CREATE TABLE submissions (
	subid		VARCHAR2(15)					CONSTRAINT pk_submissions PRIMARY KEY,
	email		VARCHAR2(50),
	name		VARCHAR2(50),
	time		DATE,
	subj		VARCHAR2(50),
	story		CLOB,
	tid		VARCHAR2(20),
	note		VARCHAR2(30),
	section		VARCHAR2(30)					CONSTRAINT nn_submissions_section NOT NULL,
	comment_text	VARCHAR2(255),
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT nn_submissions_user_id NOT NULL,
	del		NUMBER(3)	DEFAULT 0			CONSTRAINT nn_submissions_del NOT NULL
);
CREATE INDEX idx_submissions_subid ON submissions (subid, section);



DROP TABLE templates;
CREATE TABLE templates (
	tpid		NUMBER(38)					CONSTRAINT pk_templates PRIMARY KEY,
	name		VARCHAR2(30)					CONSTRAINT nn_templates_name NOT NULL,
	page		VARCHAR2(20)	DEFAULT 'misc'			CONSTRAINT nn_templates_page NOT NULL,
	section		VARCHAR2(30)	DEFAULT 'default'		CONSTRAINT nn_templates_section NOT NULL,
	lang		VARCHAR2(5)	DEFAULT 'en_US'			CONSTRAINT nn_templates_lang NOT NULL,
	template	CLOB,
	seclev		NUMBER(38),
	description	VARCHAR2(4000),
	title		VARCHAR2(128),
	CONSTRAINT	un_templates_true_template			UNIQUE (name, page, section, lang)
);
DROP SEQUENCE seq_templates;
CREATE SEQUENCE seq_templates START WITH 1;
CREATE OR REPLACE TRIGGER trg_templates_auto_inc BEFORE INSERT ON templates FOR EACH ROW
BEGIN
IF (:new.tpid IS NULL OR :new.tpid = 0) THEN
	SELECT seq_templates.nextval INTO :new.tpid FROM DUAL;
END IF;
END;



DROP TABLE topics;
CREATE TABLE topics (
	tid		VARCHAR2(20)					CONSTRAINT pk_topics PRIMARY KEY,
	image		VARCHAR2(30),
	alttext		VARCHAR2(40),
	width		NUMBER(38),
	height		NUMBER(38)
);



DROP TABLE tzcodes;
CREATE TABLE tzcodes (
	tz		VARCHAR2(3)					CONSTRAINT pk_tzcodes PRIMARY KEY,
	off_set		NUMBER(38),
	description	VARCHAR2(64)
);



DROP TABLE users;
CREATE TABLE users (
	user_id		NUMBER(38)					CONSTRAINT pk_users PRIMARY KEY,
	nickname	VARCHAR2(20)					CONSTRAINT nn_users_nickname NOT NULL,
	realemail	VARCHAR2(50)					CONSTRAINT nn_users_realemail NOT NULL,
	fakeemail	VARCHAR2(50),
	homepage	VARCHAR2(100),
	passwd		VARCHAR2(32)					CONSTRAINT nn_users_passwd NOT NULL,
	sig		VARCHAR2(160),
	seclev		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_seclev NOT NULL,
	matchname	VARCHAR2(20),
	newpasswd	VARCHAR2(8)
);
CREATE INDEX idx_users_login ON users (user_id, passwd, nickname);
CREATE INDEX idx_users_chk4user ON users (nickname, realemail);
CREATE INDEX idx_users_nickname_lookup ON users (nickname);
CREATE INDEX idx_users_chk4email ON users (realemail);
DROP SEQUENCE seq_users;
CREATE SEQUENCE seq_users START WITH 1;
CREATE OR REPLACE TRIGGER trg_users_auto_inc BEFORE INSERT ON users FOR EACH ROW
BEGIN
IF (:new.user_id IS NULL OR :new.user_id = 0) THEN
	SELECT seq_users.nextval INTO :new.user_id FROM DUAL;
END IF;
END;



DROP TABLE users_comments;
CREATE TABLE users_comments (
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT pk_users_comments PRIMARY KEY,
	points		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_comments_points NOT NULL,
	posttype	NUMBER(38)	DEFAULT 2			CONSTRAINT nn_users_comments_posttype NOT NULL,
	defaultpoints	NUMBER(38)	DEFAULT 1			CONSTRAINT nn_users_comments_defaultpt NOT NULL,
	highlightthresh	NUMBER(38)	DEFAULT 4			CONSTRAINT nn_users_comments_hlthresh NOT NULL,
	maxcommentsize	NUMBER(38)	DEFAULT 4096			CONSTRAINT nn_users_comments_maxcommentsz NOT NULL,
	hardthresh	NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_comments_hardthresh NOT NULL,
	clbig		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_comments_clbig NOT NULL,
	clsmall		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_comments_clsmall NOT NULL,
	reparent	NUMBER(3)	DEFAULT 1			CONSTRAINT nn_users_comments_reparent NOT NULL,
	nosigs		NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_comments_nosigs NOT NULL,
	commentlimit	NUMBER(38)	DEFAULT 100			CONSTRAINT nn_users_comments_commentlimit NOT NULL,
	commentspill	NUMBER(38)	DEFAULT 50			CONSTRAINT nn_users_comments_commentspill NOT NULL,
	commentsort	NUMBER(38)	DEFAULT 0,
	noscores	NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_comments_noscores NOT NULL,
	comment_mode	VARCHAR2(10)	DEFAULT 'thread',
	threshold	NUMBER(38)	DEFAULT 0
);



DROP TABLE users_index;
CREATE TABLE users_index (
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT pk_users_index PRIMARY KEY,
	extid		VARCHAR2(255),
	exaid		VARCHAR2(100),
	exsect		VARCHAR2(100),
	exboxes		VARCHAR2(255),
	maxstories	NUMBER(38)	DEFAULT 30			CONSTRAINT nn_users_index_maxstories NOT NULL,
	noboxes		NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_index_noboxes NOT NULL
);



DROP TABLE users_info;
CREATE TABLE users_info (
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT pk_users_info PRIMARY KEY,
	totalmods	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_totalmods NOT NULL,
	realname	VARCHAR2(50),
	bio		CLOB,
	tokens		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_tokens NOT NULL,
	lastgranted	DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_users_info_lastgranted NOT NULL,
	karma		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_karma NOT NULL,
	maillist	NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_info_maillist NOT NULL,
	totalcomments	NUMBER(38)	DEFAULT 0,
	lastmm		DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_users_info_lastmm NOT NULL,
	lastaccess	DATE		DEFAULT TO_DATE('0001','YYYY')	CONSTRAINT nn_users_info_lastaccess NOT NULL,
	lastmmid	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_lastmmid NOT NULL,
	m2fair		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_m2fair NOT NULL,
	m2unfair	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_m2unfair NOT NULL,
	m2fairvotes	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_m2fairvotes NOT NULL,
	m2unfairvotes	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_m2unfairvotes NOT NULL,
	upmods		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_upmods NOT NULL,
	downmods	NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_info_downmods NOT NULL,
	session_login	NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_info_session_login NOT NULL
);



DROP TABLE users_param;
CREATE TABLE users_param (
	param_id	NUMBER(38)					CONSTRAINT pk_users_param PRIMARY KEY,
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT nn_users_param_user_id NOT NULL,
	name		VARCHAR2(32)					CONSTRAINT nn_users_param_name NOT NULL,
	value		VARCHAR2(4000)					CONSTRAINT nn_users_param_value NOT NULL,
	CONSTRAINT	un_users_param_user_id_key			UNIQUE (user_id, name)
);
CREATE INDEX idx_users_param_user_id ON users_param (user_id);
DROP SEQUENCE seq_users_param;
CREATE SEQUENCE seq_users_param START WITH 1;
CREATE OR REPLACE TRIGGER trg_users_param_auto_inc BEFORE INSERT ON users_param FOR EACH ROW
BEGIN
IF (:new.param_id IS NULL OR :new.param_id = 0) THEN
	SELECT seq_users_param.nextval INTO :new.param_id FROM DUAL;
END IF;
END;



DROP TABLE users_prefs;
CREATE TABLE users_prefs (
	user_id		NUMBER(38)	DEFAULT 1			CONSTRAINT pk_users_prefs PRIMARY KEY,
	willing		NUMBER(3)	DEFAULT 1			CONSTRAINT nn_users_prefs_willing NOT NULL,
	dfid		NUMBER(38)	DEFAULT 0			CONSTRAINT nn_users_prefs_dfid NOT NULL,
	tzcode		VARCHAR2(3)	DEFAULT 'EDT'			CONSTRAINT nn_users_prefs_tzcode NOT NULL,
	noicons		NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_prefs_noicons NOT NULL,
	light		NUMBER(3)	DEFAULT 0			CONSTRAINT nn_users_prefs_light NOT NULL,
	mylinks		VARCHAR2(255)	DEFAULT 'none'			CONSTRAINT nn_users_prefs_mylinks NOT NULL,
	lang		VARCHAR2(5)	DEFAULT 'en_US'			CONSTRAINT nn_users_prefs_lang NOT NULL
);



DROP TABLE vars;
CREATE TABLE vars (
	name		VARCHAR2(32)					CONSTRAINT pk_vars PRIMARY KEY,
	value		VARCHAR2(4000),
	description	VARCHAR2(255)
);



# End of schema conversion -- everything under here is Oracle specific

DROP TABLE clob_compare;
CREATE GLOBAL TEMPORARY TABLE clob_compare (
	id		NUMBER(38),
	data		CLOB
) ON COMMIT PRESERVE ROWS;
