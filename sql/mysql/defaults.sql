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
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WAD',28800,'West Australian Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CAD',37800,'Central Australian Daylight');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EAD',39600,'Eastern Australian Daylight');
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
INSERT INTO tzcodes (tz, off_set, description) VALUES ('WAS',25200,'West Australian Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('JT',27000,'Java (3pm in Cronusland!)');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CCT',28800,'China Coast, USSR Zone 7');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('JST',32400,'Japan Standard, USSR Zone 8');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('CAS',34200,'Central Australian Standard');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EAS',36000,'Eastern Australian Standard');
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
INSERT INTO vars (name, value, description) VALUES ('admin_timeout','30','time in minutes before idle admin session ends');
INSERT INTO vars (name, value, description) VALUES ('adminmail','admin@example.com','All admin mail goes here');
INSERT INTO vars (name, value, description) VALUES ('allow_anonymous','1','allow anonymous posters');
INSERT INTO vars (name, value, description) VALUES ('allow_moderation','1','allows use of the moderation system');
INSERT INTO vars (name, value, description) VALUES ('anonymous_coward_uid', '1', 'UID to use for anonymous coward');
INSERT INTO vars (name, value, description) VALUES ('apache_cache', '3600', 'Default times for the getCurrentCache().');
INSERT INTO vars (name, value, description) VALUES ('approvedtags','B|I|P|A|LI|OL|UL|EM|BR|TT|STRONG|BLOCKQUOTE|DIV','Tags that you can use');
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
INSERT INTO vars (name, value, description) VALUES ('breaking','100','Establishes the maximum number of comments the system will display when reading comments from a "live" discussion. For stories that exceed this number of comments, there will be "page breaks" printed at the bottom. This setting does not affect "archive" mode.');
INSERT INTO vars (name, value, description) VALUES ('cache_enabled','1','Simple Boolean to determine if content is cached or not');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_debug','1','Debug _comment_text cache activity to STDERR?');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_hours','96','Discussion age at which comments are no longer cached');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_keys','3000','Maximum number of keys in the _comment_text cache');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_newstyle','0','Use _getCommentTextNew?');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_max_frac','0.75','In purging the _comment_text cache, fraction of max_keys to target');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_min_comm','50','Min number comments in a discussion for it to force a cache purge');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_min_req','5','Min number times a discussion must be requested to force a cache purge');
INSERT INTO vars (name, value, description) VALUES ('comment_maxscore','5','Maximum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_minscore','-1','Minimum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('commentsPerPoint','1000','For every X comments, valid users get a Moderator Point');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_hours','720','Hours after which a comment\'s ipid/subnetid are forgotten; set very large to disable');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_maxrows','100000','Max number of rows to forget IPs of at once');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_mincid','0','Minimum cid to start forgetting IP at');
INSERT INTO vars (name, value, description) VALUES ('comments_hardcoded','0','Turns on hardcoded layout (this is a Slashdot only feature)');
INSERT INTO vars (name, value, description) VALUES ('comments_response_limit','20','interval between reply and submit');
INSERT INTO vars (name, value, description) VALUES ('comments_speed_limit','120','seconds delay before repeat posting');
INSERT INTO vars (name, value, description) VALUES ('commentstatus','0','default comment code');
INSERT INTO vars (name, value, description) VALUES ('cookiedomain','','Domain for cookie to be active (normally leave blank)');
INSERT INTO vars (name, value, description) VALUES ('cookiepath','/','Path on server for cookie to be active');
INSERT INTO vars (name, value, description) VALUES ('cookiesecure','0','Whether or not to set secure flag in cookies if SSL is on (not working)');
INSERT INTO vars (name, value, description) VALUES ('currentqid',1,'The Current Question on the homepage pollbooth');
INSERT INTO vars (name, value, description) VALUES ('daily_attime','00:00:00','Time of day to run dailyStuff (in TZ daily_tz; 00:00:00-23:59:59)');
INSERT INTO vars (name, value, description) VALUES ('daily_last','2000-01-01 01:01:01','Last time dailyStuff was run (GMT)');
INSERT INTO vars (name, value, description) VALUES ('daily_tz','EST','Base timezone for running dailyStuff');
INSERT INTO vars (name, value, description) VALUES ('datadir','/usr/local/slash/www.example.com','What is the root of the install for Slash');
INSERT INTO vars (name, value, description) VALUES ('defaultcommentstatus','0','default code for article comments- normally 0=posting allowed');
INSERT INTO vars (name, value, description) VALUES ('defaultdisplaystatus','0','Default display status ...');
INSERT INTO vars (name, value, description) VALUES ('defaultsection','articles','Default section to display');
INSERT INTO vars (name, value, description) VALUES ('defaulttopic','1','Default topic to use');
INSERT INTO vars (name, value, description) VALUES ('delete_old_stories', '0', 'Delete stories and discussions that are older than the archive delay.');
INSERT INTO vars (name, value, description) VALUES ('discussion_archive','15','Number of days till discussions are set to read only.');
INSERT INTO vars (name, value, description) VALUES ('discussion_create_seclev','1','Seclev required to create discussions (yes, this could be an ACL in the future).');
INSERT INTO vars (name, value, description) VALUES ('discussion_default_topic', '1', 'Default topic of user-created discussions.');
INSERT INTO vars (name, value, description) VALUES ('discussion_display_limit', '30', 'Number of default discussions to list.');
INSERT INTO vars (name, value, description) VALUES ('discussionrecycle','0','Default is that recycle never occurs on recycled discussions. This number is valued in days.');
INSERT INTO vars (name, value, description) VALUES ('discussions_speed_limit','300','seconds delay before repeat discussion');
INSERT INTO vars (name, value, description) VALUES ('do_expiry','1','Flag which controls whether we expire users.');
INSERT INTO vars (name, value, description) VALUES ('down_moderations','-6','number of how many comments you can post that get down moderated');
INSERT INTO vars (name, value, description) VALUES ('fancyboxwidth','200','What size should the boxes be in?');
INSERT INTO vars (name, value, description) VALUES ('formkey_timeframe','14400','The time frame that we check for a formkey');
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
INSERT INTO vars (name, value, description) VALUES ('logdir','/usr/local/slash/www.example.com/logs','Where should the logs be found?');
INSERT INTO vars (name, value, description) VALUES ('log_admin','1','This turns on/off entries to the accesslog. If you are a small site and want a true number for your stats turn this off.');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_hitcount','3','Number of hits on comments.pl before user can be considered eligible for moderation');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_percentage','0.8','Number of hits on comments.pl before user can be considered eligible for moderation');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_end', '0.8888', 'Starting percentage into the pool of eligible moderators (used by moderatord');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_start', '0.167', 'Ending percentage into the pool of eligible moderators (used by moderatord');
INSERT INTO vars (name, value, description) VALUES ('m2_batchsize', 50, 'Maximum number of moderations processed for M2 reconciliation per execution of moderation daemon.');
INSERT INTO vars (name, value, description) VALUES ('m2_bonus','+1','Bonus for participating in meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_comments','10','Number of comments for meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus', 9, 'Number of M2 votes per M1 before it is reconciled by consensus, best if this is an odd number.')
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
INSERT INTO vars (name, value, description) VALUES ('rdfimg','http://www.example.com/images/topics/topicslash.gif','Site encoding');
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
INSERT INTO vars (name, value, description) VALUES ('template_cache_size','0','Number of templates to store in cache (0 = unlimited)');
INSERT INTO vars (name, value, description) VALUES ('template_post_chomp','0','Chomp whitespace after directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_pre_chomp','0','Chomp whitespace before directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_show_comments', '1', 'Show HTML comments before and after template (see Slash::Display)');
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
