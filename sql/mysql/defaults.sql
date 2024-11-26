#
# Host: localhost    Database: dump
#--------------------------------------------------------
# Server version	3.23.26-beta-log
#
# $Id$
#

#
# Dumping data for table 'abusers'
#


#
# Dumping data for table 'al2_types'
#

INSERT INTO al2_types VALUES (1, NULL, 'comment', 'Comment');
INSERT INTO al2_types VALUES (2, 0, 'ban', 'Ban');
INSERT INTO al2_types VALUES (3, 1, 'expired', 'Expired');
INSERT INTO al2_types VALUES (4, 2, 'nopost', 'No Comment Post');
INSERT INTO al2_types VALUES (5, 3, 'nopalm', 'No Palm');
INSERT INTO al2_types VALUES (6, 4, 'norss', 'No RSS');
INSERT INTO al2_types VALUES (7, 5, 'nosubmit', 'No Story Submit');
INSERT INTO al2_types VALUES (8, 6, 'trusted', 'Trusted');
INSERT INTO al2_types VALUES (9, 7, 'proxy', 'Valid Proxy');
INSERT INTO al2_types VALUES (10, 8, 'nopostanon', 'No Comment Post Anon');
INSERT INTO al2_types VALUES (11, 9, 'spammer', 'Spammer');
INSERT INTO al2_types VALUES (12, 10, 'openproxy', 'Open Proxy');


#
# Dumping data for table 'accesslog'
#


#
# Dumping data for table 'backup_blocks'
#


#
# Dumping data for table 'blocks'
#


INSERT INTO clout_types (clid, name, class) VALUES (1, 'describe', 'Slash::Clout::Describe');
INSERT INTO clout_types (clid, name, class) VALUES (2, 'vote',     'Slash::Clout::Vote');
INSERT INTO clout_types (clid, name, class) VALUES (3, 'moderate', 'Slash::Clout::Moderate');

#
# Dumping data for table 'code_param'
#

INSERT INTO code_param (type, code, name) VALUES ('blocktype',1,'color');
INSERT INTO code_param (type, code, name) VALUES ('blocktype',2,'static');
INSERT INTO code_param (type, code, name) VALUES ('blocktype',3,'portald');
INSERT INTO code_param (type, code, name) VALUES ('discussiontypes',0,'Discussion Enabled');
INSERT INTO code_param (type, code, name) VALUES ('discussiontypes',1,'Recycle Discussion');
INSERT INTO code_param (type, code, name) VALUES ('discussiontypes',2,'Read Only Discussion');
INSERT INTO code_param (type, code, name) VALUES ('displaycodes',0,'Always Display');
INSERT INTO code_param (type, code, name) VALUES ('displaycodes',1,'Only Display Within Section');
INSERT INTO code_param (type, code, name) VALUES ('displaycodes',-1,'Never Display');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',0,'Neither');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',1,'Article Based');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',2,'Issue Based');
INSERT INTO code_param (type, code, name) VALUES ('issuemodes',3,'Both Issue and Article');
INSERT INTO code_param (type, code, name) VALUES ('maillist',0,'Don\'t Email');
INSERT INTO code_param (type, code, name) VALUES ('maillist',1,'Email Headlines Each Night');
INSERT INTO code_param (type, code, name) VALUES ('session_login',0,'In one year');
INSERT INTO code_param (type, code, name) VALUES ('session_login',1,'When I close my browser');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',0,'Oldest First');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',1,'Newest First');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',3,'Highest Scores First');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',4,'Oldest First (Ignore Threads)');
INSERT INTO code_param (type, code, name) VALUES ('sortcodes',5,'Newest First (Ignore Threads)');
INSERT INTO code_param (type, code, name) VALUES ('sortorder', '1', 'Sort By Relevancy');
INSERT INTO code_param (type, code, name) VALUES ('sortorder', '2', 'Sort By Date (Most Recent First)');
INSERT INTO code_param (type, code, name) VALUES ('sortorder', '3', 'Sort By Date (Oldest First)');
INSERT INTO code_param (type, code, name) VALUES ('statuscodes',1,'Refreshing');
INSERT INTO code_param (type, code, name) VALUES ('statuscodes',0,'Normal');
INSERT INTO code_param (type, code, name) VALUES ('statuscodes',10,'Archive');
INSERT INTO code_param (type, code, name) VALUES ('submission-state',0,'Pending');
INSERT INTO code_param (type, code, name) VALUES ('submission-state',1,'Rejected');
INSERT INTO code_param (type, code, name) VALUES ('submission-state',2,'Accepted');
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
INSERT INTO code_param (type, code, name) VALUES ('extra_types', 1, 'text');
INSERT INTO code_param (type, code, name) VALUES ('extra_types', 2, 'list');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit', 0, '128K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit', 1, '256K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit', 2, '384K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit', 3, '512K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit', 4, '640K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit', 5, '768K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit_sub', 6, '896K');
INSERT INTO code_param (type, code, name) VALUES ('bytelimit_sub', 7, '1024K');

#
# Dumping data for table 'commentmodes'
#

INSERT INTO commentmodes (mode, name, description) VALUES ('flat','Flat','');
INSERT INTO commentmodes (mode, name, description) VALUES ('nested','Nested','');
INSERT INTO commentmodes (mode, name, description) VALUES ('thread','Threaded','');
INSERT INTO commentmodes (mode, name, description) VALUES ('nocomment','No Comments','');
INSERT INTO commentmodes (mode, name, description) VALUES ('improvedthreaded','Impoved Threaded','');

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
# Dumping data for table 'css'
#

INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','base.css','','','','no','',1,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','comments','no','',2,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','article','no','',2,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','print','print.css','','','','no','',5,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','admin.css','','','','yes','',1,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','pollBooth','no','',2,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','slashcode_lite.css','','','','no','light',4,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','journal','no','',2,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','slashcode_lite.css','','','','no','light',4,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','journal','no','',2,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','slashcode.css','','','','no','',3,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','metamod','no','',2,0, "","no");
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','slashcode_low_bw.css','','','','no','',4,99, "","yes");

#
# Dumping data for table 'css_type'
#
INSERT INTO css_type (ctid, name, ordernum) VALUES (1,'base',1);
INSERT INTO css_type (ctid, name, ordernum) VALUES (2,'page',2);
INSERT INTO css_type (ctid, name, ordernum) VALUES (3,'theme',3);
INSERT INTO css_type (ctid, name, ordernum) VALUES (4,'user_theme',5);
INSERT INTO css_type (ctid, name, ordernum) VALUES (5,'print',6);
INSERT INTO css_type (ctid, name, ordernum) VALUES (6,'skin',4);
INSERT INTO css_type (ctid, name, ordernum) VALUES (7,'handheld',7);


#
# Dumping data for table 'dateformats'
#

INSERT INTO dateformats (id, format, description) VALUES (0,'%A %B %d, @%I:%M%p IF_OLD %A %B %d %Y, @%I:%M%p','Sunday March 21, @10:00AM');
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
# Dumping data for table 'discussion_kinds'
#

INSERT INTO discussion_kinds (dkid, name) VALUES (1, 'story');
INSERT INTO discussion_kinds (dkid, name) VALUES (2, 'user_created');
INSERT INTO discussion_kinds (dkid, name) VALUES (3, 'journal');
INSERT INTO discussion_kinds (dkid, name) VALUES (4, 'journal-story');
INSERT INTO discussion_kinds (dkid, name) VALUES (5, 'poll');
INSERT INTO discussion_kinds (dkid, name) VALUES (6, 'submission');
INSERT INTO discussion_kinds (dkid, name) VALUES (7, 'feed');
INSERT INTO discussion_kinds (dkid, name) VALUES (8, 'project');

#
# Dumping data for table 'dst'
#

# as DST bill passed:
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('America',     1, 2,  2, 0, 2, 2,  1, 0, 10);
# old America dst line ... still used by Canada, Mexico, others?  maybe make an America region, and a U.S. region, and have new non-U.S. versions of the timezones?
# or make timezone selectable?  (Rob was against this before)
#INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('America',     1, 2,  1, 0, 3, 2, -1, 0,  9);
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('Europe',      1, 1, -1, 0, 2, 1, -1, 0,  9);
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('Australia',   1, 2, -1, 0, 9, 2, -1, 0,  2);
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('New Zealand', 0, 2,  1, 0, 9, 2,  3, 0,  2);


#
# Dumping data for table 'globj_types'
#

INSERT INTO globj_types VALUES (NULL, 'stories');
INSERT INTO globj_types VALUES (NULL, 'urls');
INSERT INTO globj_types VALUES (NULL, 'submissions');
INSERT INTO globj_types VALUES (NULL, 'journals');
INSERT INTO globj_types VALUES (NULL, 'comments');
INSERT INTO globj_types VALUES (NULL, 'projects');
INSERT INTO globj_types VALUES (NULL, 'preview');


#
# Dumping data for table 'hitters'
#


#
# Dumping data for table 'menus'
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
# Dumping data for table 'sessions'
#

INSERT INTO shill_ids VALUES (1, 'Admin');
INSERT INTO shill_ids VALUES (2, 'ThinkGeek');

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
# Dumping data for table 'string_param'
#

INSERT INTO string_param (type, code, name) VALUES ('commentcodes','disabled','Comments Disabled');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes','enabled','Comments Enabled');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','friends_only','Just Friends');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','friends_fof_only','Just Friends and their Friends');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','no_foe','No Foes');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','no_foe_eof','No Foes and No Friend\'s Foes');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','logged_in','Only Logged-In Users');
INSERT INTO string_param (type, code, name) VALUES ('cookie_location','none','Everywhere');
INSERT INTO string_param (type, code, name) VALUES ('cookie_location','classbid','My Subnet');
INSERT INTO string_param (type, code, name) VALUES ('cookie_location','ipid','My IP Address');
INSERT INTO string_param (type, code, name) VALUES ('yes_no','yes','yes');
INSERT INTO string_param (type, code, name) VALUES ('yes_no','no','no');
INSERT INTO string_param (type, code, name) VALUES ('story023','0','Never');
INSERT INTO string_param (type, code, name) VALUES ('story023','2','Often');
INSERT INTO string_param (type, code, name) VALUES ('story023','3','Always');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','','Unclassified');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','Hold','Hold');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','Quick','Quick');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','Back','Back');


INSERT INTO string_param (type, code, name) VALUES ('us_states','AL','Alabama');
INSERT INTO string_param (type, code, name) VALUES ('us_states','AK','Alaska');
INSERT INTO string_param (type, code, name) VALUES ('us_states','AS','American Samoa');
INSERT INTO string_param (type, code, name) VALUES ('us_states','AZ','Arizona');
INSERT INTO string_param (type, code, name) VALUES ('us_states','AR','Arkansas');
INSERT INTO string_param (type, code, name) VALUES ('us_states','CA','California');
INSERT INTO string_param (type, code, name) VALUES ('us_states','CO','Colorado');
INSERT INTO string_param (type, code, name) VALUES ('us_states','CT','Connecticut');
INSERT INTO string_param (type, code, name) VALUES ('us_states','DE','Delaware');
INSERT INTO string_param (type, code, name) VALUES ('us_states','DC','District of Columbia');
INSERT INTO string_param (type, code, name) VALUES ('us_states','FM','Federated States of Micronesia');
INSERT INTO string_param (type, code, name) VALUES ('us_states','FL','Florida');
INSERT INTO string_param (type, code, name) VALUES ('us_states','GA','Georgia');
INSERT INTO string_param (type, code, name) VALUES ('us_states','GU','Guam');
INSERT INTO string_param (type, code, name) VALUES ('us_states','HI','Hawaii');
INSERT INTO string_param (type, code, name) VALUES ('us_states','ID','Idaho');
INSERT INTO string_param (type, code, name) VALUES ('us_states','IL','Illinois');
INSERT INTO string_param (type, code, name) VALUES ('us_states','IN','Indiana');
INSERT INTO string_param (type, code, name) VALUES ('us_states','IA','Iowa');
INSERT INTO string_param (type, code, name) VALUES ('us_states','KS','Kansas');
INSERT INTO string_param (type, code, name) VALUES ('us_states','KY','Kentucky');
INSERT INTO string_param (type, code, name) VALUES ('us_states','LA','Louisiana');
INSERT INTO string_param (type, code, name) VALUES ('us_states','ME','Maine');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MH','Marshall Islands');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MD','Maryland');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MA','Massachusetts');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MI','Michigan');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MN','Minnesota');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MS','Mississippi');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MO','Missouri');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MT','Montana');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NE','Nebraska');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NV','Nevada');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NH','New Hampshire');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NJ','New Jersey');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NM','New Mexico');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NY','New York');
INSERT INTO string_param (type, code, name) VALUES ('us_states','NC','North Carolina');
INSERT INTO string_param (type, code, name) VALUES ('us_states','ND','North Dakota');
INSERT INTO string_param (type, code, name) VALUES ('us_states','MP','Northern Mariana Islands');
INSERT INTO string_param (type, code, name) VALUES ('us_states','OH','Ohio');
INSERT INTO string_param (type, code, name) VALUES ('us_states','OK','Oklahoma');
INSERT INTO string_param (type, code, name) VALUES ('us_states','OR','Oregon');
INSERT INTO string_param (type, code, name) VALUES ('us_states','PW','Palau');
INSERT INTO string_param (type, code, name) VALUES ('us_states','PA','Pennsylvania');
INSERT INTO string_param (type, code, name) VALUES ('us_states','PR','Puerto Rico');
INSERT INTO string_param (type, code, name) VALUES ('us_states','RI','Rhode Island');
INSERT INTO string_param (type, code, name) VALUES ('us_states','SC','South Carolina');
INSERT INTO string_param (type, code, name) VALUES ('us_states','SD','South Dakota');
INSERT INTO string_param (type, code, name) VALUES ('us_states','TN','Tennessee');
INSERT INTO string_param (type, code, name) VALUES ('us_states','TX','Texas');
INSERT INTO string_param (type, code, name) VALUES ('us_states','UT','Utah');
INSERT INTO string_param (type, code, name) VALUES ('us_states','VT','Vermont');
INSERT INTO string_param (type, code, name) VALUES ('us_states','VI','Virgin Islands');
INSERT INTO string_param (type, code, name) VALUES ('us_states','VA','Virginia');
INSERT INTO string_param (type, code, name) VALUES ('us_states','WA','Washington');
INSERT INTO string_param (type, code, name) VALUES ('us_states','WV','West Virginia');
INSERT INTO string_param (type, code, name) VALUES ('us_states','WI','Wisconsin');
INSERT INTO string_param (type, code, name) VALUES ('us_states','WY','Wyoming');

INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','AB','Alberta');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','BC','British Columbia');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','MB','Manitoba');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','NB','New Brunswick');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','NL','Newfoundland and Labrador');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','NT','Northwest Territories');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','NS','Nova Scotia');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','NU','Nunavut');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','ON','Ontario');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','PE','Prince Edward Island');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','QC','Quebec');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','SK','Saskatchewan');
INSERT INTO string_param (type, code, name) VALUES ('ca_provinces','YT','Yukon');

-- ISO Country Names and Abbreviations (ISO 3166)
-- http://www.iso.org/iso/en/prods-services/iso3166ma/02iso-3166-code-lists/list-en1.html

INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VA','Holy See (Vatican City State)');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NP','Nepal');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NO','Norway');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NL','Netherlands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NI','Nicaragua');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','UZ','Uzbekistan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','UY','Uruguay');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NG','Nigeria');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NF','Norfolk Island');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NE','Niger');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NC','New Caledonia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','FR','France');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','US','United States');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NA','Namibia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','FO','Faroe Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','FM','Micronesia, Federated States of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','UM','United States Minor Outlying Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','FK','Falkland Islands (Malvinas)');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','FJ','Fiji');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','FI','Finland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MZ','Mozambique');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MY','Malaysia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MX','Mexico');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MW','Malawi');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MV','Maldives');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','UG','Uganda');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MU','Mauritius');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MT','Malta');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MS','Montserrat');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MR','Mauritania');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MQ','Martinique');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','UA','Ukraine');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MP','Northern Mariana Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MO','Macao');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MN','Mongolia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MM','Myanmar');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ML','Mali');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MK','Macedonia, the Former Yugoslav Republic of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TZ','Tanzania, United Republic of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MH','Marshall Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MG','Madagascar');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TW','Taiwan, Province of China');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TV','Tuvalu');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ET','Ethiopia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MD','Moldova, Republic of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MC','Monaco');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ES','Spain');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TT','Trinidad and Tobago');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ER','Eritrea');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','MA','Morocco');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TR','Turkey');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TO','Tonga');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TN','Tunisia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TM','Turkmenistan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TL','East Timor');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TK','Tokelau');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LY','Libyan Arab Jamahiriya');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TJ','Tajikistan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','EH','Western Sahara');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','EG','Egypt');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TH','Thailand');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','EE','Estonia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LV','Latvia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TG','Togo');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TF','French Southern Territories');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LU','Luxembourg');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','EC','Ecuador');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LT','Lithuania');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TD','Chad');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LS','Lesotho');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','TC','Turks and Caicos Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LR','Liberia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LK','Sri Lanka');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','DZ','Algeria');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LI','Liechtenstein');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SZ','Swaziland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SY','Syrian Arab Republic');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SV','El Salvador');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LC','Saint Lucia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ST','Sao Tome and Principe');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LB','Lebanon');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','LA','Lao People\'s Democratic Republic');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SR','Suriname');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','DO','Dominican Republic');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SO','Somalia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','DM','Dominica');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SN','Senegal');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SM','San Marino');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','DK','Denmark');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','DJ','Djibouti');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SL','Sierra Leone');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KZ','Kazakhstan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SK','Slovakia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KY','Cayman Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SJ','Svalbard and Jan Mayen');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SI','Slovenia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KW','Kuwait');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SH','Saint Helena');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','DE','Germany');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SG','Singapore');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ZW','Zimbabwe');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SE','Sweden');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SD','Sudan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SC','Seychelles');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KR','Korea, Republic of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SB','Solomon Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','SA','Saudi Arabia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KP','Korea, Democratic People\'s Republic of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KN','Saint Kitts and Nevis');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KM','Comoros');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ZM','Zambia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CZ','Czech Republic');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CY','Cyprus');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KI','Kiribati');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CX','Christmas Island');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KH','Cambodia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KG','Kyrgyzstan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CV','Cape Verde');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','RW','Rwanda');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CU','Cuba');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','KE','Kenya');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','RU','Russian Federation');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CR','Costa Rica');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CO','Colombia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ZA','South Africa');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CN','China');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','RO','Romania');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CM','Cameroon');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CL','Chile');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CK','Cook Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CI','C&ocirc;te D\'Ivoire');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CH','Switzerland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CG','Congo');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CF','Central African Republic');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CD','Congo, the Democratic Republic of the');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CC','Cocos (Keeling) Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','RE','R&eacute;union');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','YU','Yugoslavia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','CA','Canada');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','YT','Mayotte');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','JP','Japan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','JO','Jordan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','JM','Jamaica');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BZ','Belize');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BY','Belarus');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BW','Botswana');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BV','Bouvet Island');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BT','Bhutan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BS','Bahamas');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','YE','Yemen');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BR','Brazil');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BO','Bolivia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BN','Brunei Darussalam');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BM','Bermuda');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BJ','Benin');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BI','Burundi');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BH','Bahrain');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BG','Bulgaria');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BF','Burkina Faso');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BE','Belgium');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BD','Bangladesh');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BB','Barbados');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IT','Italy');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','BA','Bosnia and Herzegovina');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IS','Iceland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IR','Iran, Islamic Republic of');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IQ','Iraq');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','QA','Qatar');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IO','British Indian Ocean Territory');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IN','India');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IL','Israel');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AZ','Azerbaijan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VC','Saint Vincent and the Grenadines');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NR','Nauru');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GA','Gabon');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GB','United Kingdom');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VE','Venezuela');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NU','Niue');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GD','Grenada');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VG','Virgin Islands, British');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GE','Georgia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GF','French Guiana');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VI','Virgin Islands, U.S.');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GH','Ghana');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','NZ','New Zealand');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GI','Gibraltar');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GL','Greenland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VN','Viet Nam');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GM','Gambia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GN','Guinea');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GP','Guadeloupe');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GQ','Equatorial Guinea');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GR','Greece');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GS','South Georgia and the South Sandwich Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','VU','Vanuatu');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GT','Guatemala');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GU','Guam');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GW','Guinea-Bissau');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','GY','Guyana');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','OM','Oman');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','WF','Wallis and Futuna');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','HK','Hong Kong');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','HM','Heard Island and Mcdonald Islands');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','HN','Honduras');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PA','Panama');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','WS','Samoa');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','HR','Croatia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','HT','Haiti');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PE','Peru');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','HU','Hungary');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PF','French Polynesia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AD','Andorra');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AE','United Arab Emirates');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PG','Papua New Guinea');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PH','Philippines');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AF','Afghanistan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AG','Antigua and Barbuda');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PK','Pakistan');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AI','Anguilla');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PL','Poland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PM','Saint Pierre and Miquelon');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PN','Pitcairn');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AL','Albania');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AM','Armenia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AN','Netherlands Antilles');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AO','Angola');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PR','Puerto Rico');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AQ','Antarctica');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PS','Palestinian Territory, Occupied');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AR','Argentina');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PT','Portugal');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AS','American Samoa');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AT','Austria');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','ID','Indonesia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AU','Australia');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','IE','Ireland');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PW','Palau');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','AW','Aruba');
INSERT INTO string_param (type, code, name) VALUES ('iso_countries','PY','Paraguay');


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

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('UTC',       0, 'Universal Coordinated',         NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('IDLW', -43200, 'International Date Line West',  NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('IDLE',  43200, 'International Date Line East',  NULL,          NULL,    NULL);

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('GMT',       0, 'Greenwich Mean',                NULL,          NULL,    NULL);

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('WET',       0, 'Western European',             'Europe',      'WEST',   3600);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('CET',    3600, 'Central European',             'Europe',      'CEST',   7200);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('EET',    7200, 'Eastern European',             'Europe',      'EEST',  10800);

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('BT',    10800, 'Baghdad, USSR Zone 2',          NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('IT',    12600, 'Iran',                          NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('ZP4',   14400, 'USSR Zone 3',                   NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('ZP5',   18000, 'USSR Zone 4',                   NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('IST',   19800, 'Indian',                        NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('ZP6',   21600, 'USSR Zone 5',                   NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('ZP7',   25200, 'USSR Zone 6',                   NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('JT',    27000, 'Java',                          NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('CCT',   28800, 'China Coast, USSR Zone 7',      NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('JST',   32400, 'Japan, USSR Zone 8',            NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('KST',   32400, 'Korean',                        NULL,         'KDT',   36000);

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('AWST',  28800, 'Western Australian',           'Australia',   'AWDT',  32400);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('ACST',  34200, 'Central Australian',           'Australia',   'ACDT',  37800);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('AEST',  36000, 'Eastern Australian',           'Australia',   'AEDT',  39600);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('MAGS',  39600, 'Magadan',                       NULL,         'MAGD', 43200);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('NZST',  43200, 'New Zealand',                  'New Zealand', 'NZDT',  46800);

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('WAT',   -3600, 'West Africa',                   NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('AT',    -7200, 'Azores',                        NULL,          NULL,    NULL);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('GST',  -10800, 'Greenland',                     NULL,          NULL,    NULL);

INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('NST',  -12600, 'Newfoundland',                 'America',     'NDT',   -9000);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('AST',  -14400, 'Atlantic',                     'America',     'ADT',  -10800);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('EST',  -18000, 'Eastern',                      'America',     'EDT',  -14400);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('CST',  -21600, 'Central',                      'America',     'CDT',  -18000);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('MST',  -25200, 'Mountain',                     'America',     'MDT',  -21600);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('PST',  -28800, 'Pacific',                      'America',     'PDT',  -25200);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('AKST', -32400, 'Alaska',                       'America',     'AKDT', -28800);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('HAST', -36000, 'Hawaii-Aleutian',              'America',     'HADT', -32400);
INSERT INTO tzcodes (tz, off_set, description, dst_region, dst_tz, dst_off_set) VALUES ('NT',   -39600, 'Nome',                          NULL,          NULL,    NULL);

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

# PLEASE KEEP THESE SORTED.  There are tons of vars, and it is a PITA
# to have to find them when they are not in alphabetical order.

INSERT INTO vars (name, value, description) VALUES ('absolutedir','http://www.example.com','Absolute base URL of site; used for creating links external to site that need a complete URL');
INSERT INTO vars (name, value, description) VALUES ('absolutedir_secure','','Absolute base URL of Secure HTTP site (blank if site has no HTTPS side)');
INSERT INTO vars (name, value, description) VALUES ('accesslog_disable','0','Disable apache writing to accesslog?');
INSERT INTO vars (name, value, description) VALUES ('accesslog_css_skip', '1', 'Skip logging css hits to accesslog table?');
INSERT INTO vars (name, value, description) VALUES ('accesslog_hoursback', '60', 'Number of hours before accesslog rows are purged');
INSERT INTO vars (name, value, description) VALUES ('accesslog_imageregex', '^/images/hc/', 'Image hits will only be written into accesslog if their URL path matches this regex, empty string for all, NONE for none');
INSERT INTO vars (name, value, description) VALUES ('accesslog_insert_cachesize','0','Cache accesslog inserts and do this many all at once (0 to disable, if enabled, suggest value of 5 or so)');
INSERT INTO vars (name, value, description) VALUES ('ad_max', '6', 'Maximum ad number (must be at least ad_messaging_num)');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_num', '6', 'Which ad (env var AD_BANNER_x) is the "messaging ad"?');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_prob', '0.5', 'Probability that the messaging ad will be shown, if the circumstances are right');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_sections', '', 'Vertbar-separated list of sections where messaging ads can appear; if empty, all sections');
INSERT INTO vars (name, value, description) VALUES ('admin_check_clearpass', '0', 'Check whether admins have sent their Slash passwords in the clear?');
INSERT INTO vars (name, value, description) VALUES ('admin_clearpass_disable', '0', 'Should admins who send their Slash passwords in the clear have their admin privileges removed until they change their passwords?');
INSERT INTO vars (name, value, description) VALUES ('admin_formkeys', '0', 'Do admins have to bother with formkeys?');
INSERT INTO vars (name, value, description) VALUES ('admin_secure_ip_regex', '^127\\.', 'IP addresses or networks known to be secure.');
INSERT INTO vars (name, value, description) VALUES ('admin_story_lookahead_default', 365*86400, 'In the admin.pl storylist, how many seconds to look into the future for all stories by default (but see skins_admin_story_lookahead_mainpage)');
INSERT INTO vars (name, value, description) VALUES ('admin_story_lookahead_infinite', '0', 'In the admin.pl storylist, always show all future stories no matter how far in the future?');
INSERT INTO vars (name, value, description) VALUES ('admin_story_lookahead_mainpage', 72*3600, 'In the admin.pl storylist, how many seconds to look into the future for stories on the mainpage');
INSERT INTO vars (name, value, description) VALUES ('admin_use_blob_for_upload', '1', 'Use blobs for fileuploading - 1 for yes, 0 for no or file-based uploading');
INSERT INTO vars (name, value, description) VALUES ('admin_warn_primaryskid', '', 'Warn admin if a story is saved with the following primaryskids (skids delimited by |)');
INSERT INTO vars (name, value, description) VALUES ('admin_timeout','30','time in minutes before idle admin session ends');
INSERT INTO vars (name, value, description) VALUES ('adminmail','admin@example.com','All admin mail goes here');
INSERT INTO vars (name, value, description) VALUES ('adminmail_ban','admin@example.com','All admin mail about users being banned goes here');
INSERT INTO vars (name, value, description) VALUES ('adminmail_check_replication', 0, 'Check replication if is caught up before starting adminmail');
INSERT INTO vars (name, value, description) VALUES ('adminmail_mod','admin@example.com','All admin mail about moderation goes here');
INSERT INTO vars (name, value, description) VALUES ('adminmail_post','admin@example.com','All admin mail about comment posting goes here');
INSERT IGNORE INTO vars (name, value, description) VALUES ('al2_type_aliases', 'spammer->nosubmit spammer->nopost nopost->nopostanon', 'List of AL2s that imply other AL2s, in a whitespace-delimited list of A->B format');
INSERT INTO vars (name, value, description) VALUES ('allow_anonymous','1','allow anonymous posters');
INSERT INTO vars (name, value, description) VALUES ('allow_nonadmin_ssl','0','0=users with seclev <= 1 cannot access the site over Secure HTTP; 1=they all can; 2=only if they are subscribers');
INSERT INTO vars (name, value, description) VALUES ('allow_other_users_comments', '0', 'Allow users to view the comments of other users the other users info page');
INSERT INTO vars (name, value, description) VALUES ('anonymous_coward_uid', '1', 'UID to use for anonymous coward');
INSERT INTO vars (name, value, description) VALUES ('anon_name','Anonymous Coward','Name of anonymous user to be displayed in stories');
INSERT INTO vars (name, value, description) VALUES ('anon_name_alt','An Anonymous Coward','Name of anonymous user (only used in submit.pl)');
INSERT INTO vars (name, value, description) VALUES ('apache_cache', '3600', 'Default times for the getCurrentCache().');
INSERT INTO vars (name, value, description) VALUES ('approved_url_schemes','ftp|http|gopher|mailto|news|nntp|telnet|wais|https','Schemes that can be used in comment links without being stripped of bogus chars');
INSERT INTO vars (name, value, description) VALUES ('approvedtags','b|i|p|br|a|ol|ul|li|dl|dt|dd|em|strong|tt|blockquote|div|ecode|quote|sup|sub|strike|abbr|sarc|sarcasm|user','Tags that you can use');
INSERT INTO vars (name, value, description) VALUES ('approvedtags_attr', 'a:href_RU img:src_RU,alt_N,width,height,longdesc_U p:class div:class abbr:title_RU', 'definition of approvedtags attributes in the following format a:href_RU img:src_RU,alt,width,height,longdesc_U see Slash::Utility::Data.pm for more details');
INSERT INTO vars (name, value, description) VALUES ('approvedtags_attr_admin', 'a:href_U,name,title,rel div:id,class,title,style,dir,lang span:id,class,title,style,dir,lang slash:type_R,id,href_U,story,nickname,uid,user,align,width,height,title table:align,bgcolor,border,cellpadding,cellspacing,width tr:align,bgcolor,valign th:align,bgcolor,colspan,height,rowspan,valign,width td:align,bgcolor,colspan,height,rowspan,valign,width', 'inherits from approvedtags_attr');
INSERT INTO vars (name, value, description) VALUES ('approvedtags_break','p|br|ol|ul|li|dl|dt|dd|blockquote|div|img|hr|h1|h2|h3|h4|h5|h6|quote','Tags that break words (see breakHtml())');
INSERT INTO vars (name, value, description) VALUES ('approvedtags_visible', 'b|i|p|br|a|ol|ul|li|dl|dt|dd|em|strong|tt|blockquote|div|ecode|quote|strike|sarc|sarcasm|user', 'tags that show in the availible list shown to users. for easter-egg purposes mostly.');
INSERT INTO vars (name, value, description) VALUES ('archive_delay','0','days to wait for story archiving, set to 0 to disable');
INSERT INTO vars (name, value, description) VALUES ('archive_delay_mod','60','Days before moderator logs are expired');
INSERT INTO vars (name, value, description) VALUES ('articles_only','0','show only Articles in submission count in admin menu');
INSERT INTO vars (name, value, description) VALUES ('article_nocomment','0','Show no comments in article.pl');
INSERT INTO vars (name, value, description) VALUES ('authors_unlimited','1000000','Seclev for which authors have unlimited comment-moderation and -deletion power (see also the ACLs)');
INSERT INTO vars (name, value, description) VALUES ('backup_db_user','','The virtual user of the database that the code should use for intensive database access that may bring down the live site. If you don\'t know what this is for, you should leave it blank.');
INSERT INTO vars (name, value, description) VALUES ('badge_icon_ext', 'gif', 'Badge icon extension ("gif" or "png", probably)');
INSERT INTO vars (name, value, description) VALUES ('badge_icon_size', '15', 'Badge icon height/width');
INSERT INTO vars (name, value, description) VALUES ('badge_icon_size_wide', '15', 'Badge icon width for wide icons');
INSERT INTO vars (name, value, description) VALUES ('badkarma','-10','Users get penalized for posts if karma is below this value');
INSERT INTO vars (name, value, description) VALUES ('bad_password_warn_ip','40','Warn admin if an ip specifies password incorrectly this many times in one day');
INSERT INTO vars (name, value, description) VALUES ('bad_password_warn_subnet','60','Warn admin if a subnet specifies password incorrectly this many times in one day');
INSERT INTO vars (name, value, description) VALUES ('bad_password_warn_uid','40','Warn admin if user specifies password incorrectly this many times in one day');
INSERT INTO vars (name, value, description) VALUES ('bad_password_warn_user_interval','30','Warn a user on the Nth bad password attempt within 24 hours. Set to 0 if you do not want users to be warned');
INSERT INTO vars (name, value, description) VALUES ('banlist_expire','900','Default expiration time for the banlist cache');
INSERT INTO vars (name, value, description) VALUES ('basedir','/usr/local/slash/www.example.com/htdocs','Where should the html/perl files be found?');
INSERT INTO vars (name, value, description) VALUES ('basedomain','www.example.com','The URL for the site');
INSERT INTO vars (name, value, description) VALUES ('block_expire','3600','Default expiration time for the block cache');
INSERT INTO vars (name, value, description) VALUES ('body_bytes','0','Use Slashdot like byte message instead of word count on stories');
INSERT INTO vars (name, value, description) VALUES ('breakhtml_wordlength','50','Maximum word length before whitespace is inserted in comments');
INSERT INTO vars (name, value, description) VALUES ('breaking','100','Establishes the maximum number of comments the system will display when reading comments from a "live" discussion. For stories that exceed this number of comments, there will be "page breaks" printed at the bottom. This setting does not affect "archive" mode.');
INSERT INTO vars (name, value, description) VALUES ('bytime_delay','120','days to go back for next/previous links on stories');
INSERT INTO vars (name, value, description) VALUES ('cache_enabled','1','Simple Boolean to determine if content is cached or not');
INSERT INTO vars (name, value, description) VALUES ('cache_enabled_template','1','If set, then template caching is still active even if var cache_enabled is turned off.');
INSERT INTO vars (name, value, description) VALUES ('charrefs_bad_entity','zwnj|zwj|lrm|rlm','Entities that approveCharref should always delete');
INSERT INTO vars (name, value, description) VALUES ('charrefs_bad_numeric','8204|8205|8206|8207|8236|8237|8238','Numeric references that approveCharref should always delete');
INSERT INTO vars (name, value, description) VALUES ('checklist_length','255','Length of user_index checklist fields (default is VARCHAR(255))');
INSERT INTO vars (name, value, description) VALUES ('clientip_xff_trust_regex','^127\\.0\\.0\\.1$','IP addresses from which we will trust an X-Real-IP header');
INSERT INTO vars (name, value, description) VALUES ('clientip_xff_trust_header','','Name of HTTP request header to prefer over "X-Real-IP", if present');
INSERT INTO vars (name, value, description) VALUES ('cookie_location','classbid','Default for user\'s cookie_location value (also see users_info schema!)');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_hours','96','Discussion age at which comments are no longer cached');
INSERT INTO vars (name, value, description) VALUES ('comment_compress_slice','500','Chars to slice comment into for compressOk');
INSERT INTO vars (name, value, description) VALUES ('comment_homepage_disp','50','Chars of poster URL to show in comment header');
INSERT INTO vars (name, value, description) VALUES ('comment_commentlimit','250','Max commentlimit users can set');
INSERT INTO vars (name, value, description) VALUES ('comment_karma_limit','','Max karma that a single comment can cost a user, normally negative values or 0 to never take karma with downmods, empty string for unlimited');
INSERT INTO vars (name, value, description) VALUES ('comment_maxscore','5','Maximum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_minscore','-1','Minimum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_nonstartwordchars','.,;:/','Chars which cannot start a word (will be forcibly separated from the rest of the word by a space) - this works around a Windows/MSIE "widening" bug - set blank for no action');
INSERT INTO vars (name, value, description) VALUES ('comment_startword_workaround','1','Should breakHtml() insert kludgy HTML to work around an MSIE bug?');
INSERT INTO vars (name, value, description) VALUES ('comments_codemode_wsfactor','0.5','Whitespace factor for CODE posting mode');
INSERT INTO vars (name, value, description) VALUES ('comments_control_horizontal', '0', 'Is Discussion2 control is configured horizontally?');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_hours','720','Hours after which a comment\'s ipid/subnetid are forgotten; set very large to disable');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_maxrows','100000','Max number of rows to forget IPs of at once');
INSERT INTO vars (name, value, description) VALUES ('comments_forgetip_mincid','0','Minimum cid to start forgetting IP at');
INSERT INTO vars (name, value, description) VALUES ('comments_hardcoded','0','Turns on hardcoded layout (this is a Slashdot only feature)');
INSERT INTO vars (name, value, description) VALUES ('comments_mod_totals_exact','1','Show exact moderation counts?');
INSERT INTO vars (name, value, description) VALUES ('comments_more_seclev','100','Seclev required to see More Comments (special: 2 means subscribers)');
INSERT INTO vars (name, value, description) VALUES ('comments_perday_bykarma','-1=2|25=25|99999=50','Number of comments allowed to be posted per day, by karma score.');
INSERT INTO vars (name, value, description) VALUES ('comments_perday_anon','10','Number of comments allowed to be posted per day, by any one IPID, anonymously.');
INSERT INTO vars (name, value, description) VALUES ('comments_max_email_len','40','Max num of chars of fakeemail to display in comment header');
INSERT INTO vars (name, value, description) VALUES ('comments_min_line_len','10','Minimum minimum average line length');
INSERT INTO vars (name, value, description) VALUES ('comments_min_line_len_kicks_in','100','Num chars at which minimum average line length first takes effect');
INSERT INTO vars (name, value, description) VALUES ('comments_min_line_len_max','20','Maximum minimum average line length');
INSERT INTO vars (name, value, description) VALUES ('comments_moddable_archived','0','Are comments in discussions that have been archived moderatable?');
INSERT INTO vars (name, value, description) VALUES ('comments_moddable_hours','336','Num hours after being posted that a comment may be moderated');
INSERT INTO vars (name, value, description) VALUES ('comments_portscan', '0', 'Scan incoming IPs for open proxy ports? 0=never, 1=anon posting only, 2=all posting');
INSERT INTO vars (name, value, description) VALUES ('comments_portscan_cachehours', '48', 'If comments_portscan_anon_for_proxy is true, hours to cache a result of a portscan for open proxies on a particular IP');
INSERT INTO vars (name, value, description) VALUES ('comments_portscan_ports', '80 8080 8000 3128', 'If comments_portscan_anon_for_proxy is true, scan these space-separated ports');
INSERT INTO vars (name, value, description) VALUES ('comments_portscan_timeout', '5', 'If comments_portscan_anon_for_proxy is true, use this as timeout');
INSERT INTO vars (name, value, description) VALUES ('comments_response_limit','5','interval between reply and submit');
INSERT INTO vars (name, value, description) VALUES ('comments_anon_speed_limit','0','seconds delay before repeat posting for anonymous user.  If 0 uses default speed_limit for all users');
INSERT INTO vars (name, value, description) VALUES ('comments_speed_limit','120','seconds delay before repeat posting');
INSERT INTO vars (name, value, description) VALUES ('comments_anon_speed_limit_mult','1', 'Multiply speedlimit by this amount for each comment previously posted in the past 24 hours');
INSERT INTO vars (name, value, description) VALUES ('comments_wsfactor','1.0','Whitespace factor');
INSERT INTO vars (name, value, description) VALUES ('commentstatus','0','default comment code');
INSERT INTO vars (name, value, description) VALUES ('common_story_words', 'about above across after again against almost along already also although always among another anyone arise around aside asked available away became because become becomes been before began behind being better between both brought called came can\'t cannot certain certainly come could days didn\'t different does done down during each either else enough especially even ever every fact find following form found from further gave gets give given gives giving going gone hardly have having here himself however http important into it\'s itself just keep kept knew know known largely later least like look made mainly make many maybe might more most mostly much must nearly neither never next none noted nothing obtain obtained often once only other others ought over overall owing particularly past people perhaps please possible present probably quite rather read ready really right said same saying says seem seems seen several shall should show showed shown shows similar similarly since some something sometime sometimes somewhat soon such sure take taken tell than that that\'s their theirs them themselves then there therefore these they thing things think this those though through throughout thus time together told took toward turn under unless until upon used using usually various very want well were what what when where whether which while whole whom whose wide widely will will with within without would year years your', 'Words which are considered too common to be used in detecting "similar" stories');
INSERT INTO vars (name, value, description) VALUES ('content_type_webpage','text/html; charset=iso-8859-1','The Content-Type header for webpages');
INSERT INTO vars (name, value, description) VALUES ('cookiedomain','','Domain for cookie to be active (normally leave blank)');
INSERT INTO vars (name, value, description) VALUES ('cookiepath','/','Path on server for cookie to be active');
INSERT INTO vars (name, value, description) VALUES ('cookiesecure','1','Set the secure flag in cookies if SSL is on?');
INSERT INTO vars (name, value, description) VALUES ('counthits_lastmaxid','1','Last accesslog id scanned by counthits task');
INSERT INTO vars (name, value, description) VALUES ('css_expire','3600','Time in seconds before css cache expires');
INSERT INTO vars (name, value, description) VALUES ('css_use_imagedir','0','Place .css files in imagedir instead for your rootdir?  You may want to utilize this if you are using boa or another lightweight webserver to serve images.  Run symlink-tool after switching var');
INSERT INTO vars (name, value, description) VALUES ('cur_performance_pps', '', 'Pages per second the site is running at');
INSERT INTO vars (name, value, description) VALUES ('cur_performance_stats', '', 'Stores current performance stats in a var for display to admins');
INSERT INTO vars (name, value, description) VALUES ('cur_performance_stats_disp', '1', 'Show current performance stats?');
INSERT INTO vars (name, value, description) VALUES ('cur_performance_stat_ops', 'article|comments|index', 'ops to show current performance stats for');
INSERT INTO vars (name, value, description) VALUES ('cur_performance_stats_lastid', '0', 'accesslogid to start searching at');
INSERT INTO vars (name, value, description) VALUES ('cur_performance_stats_weeks', '8', 'number of weeks back to compare current stats to');
INSERT INTO vars (name, value, description) VALUES ('currentqid',1,'The Current Question on the homepage pollbooth');
INSERT INTO vars (name, value, description) VALUES ('cvs_tag_currentcode','rehash_16_00','The current cvs tag that the code was updated to - this does not affect site behavior but may be useful for your records');
INSERT INTO vars (name, value, description) VALUES ('datadir','/usr/local/slash/www.example.com','What is the root of the install for Slash');
INSERT INTO vars (name, value, description) VALUES ('db_auto_increment_increment','1','If your master DB uses auto_increment_increment, i.e. multiple master replication, echo its value into this var');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_disp','0','Display dbsparklines in the currentAdminUsers box?');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_height',40,'Pixel height of sparkline graphs');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_pngsuffix',FLOOR(RAND()*900000000+100000000),'Random number to make it hard for unauthorized users to read these PNGs without permission');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_secsback',30*60,'How many seconds to look back for the sparklines');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_width',150,'Pixel width of sparkline graphs');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_ymax',20,'Max bog value (clip higher values to this)');
INSERT INTO vars (name, value, description) VALUES ('dbsparklines_ymin',-20,'Min lag value (clip lower values to this) - should be negative');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_adjust_delay','5','Number of seconds between each adjustment of reader DB weights');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_bog_secs_start','5','Number of seconds of reader DB bog at which balance_readers.pl should start to reduce its weight');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_bog_secs_end','60','Number of seconds of reader DB bog at which balance_readers.pl hits the minimum weight');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_bog_weight_min','0.2','The minimum weight to multiply a reader DB\'s base weight by once its bog hits dbs_reader_bog_secs_end');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_expire_secs', 86400 * 7,'Number of seconds worth of dbs_readerstatus log to keep around');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_lag_secs_start','5','Number of seconds of reader DB lag at which balance_readers.pl should start to reduce its weight');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_lag_secs_end','30','Number of seconds of reader DB lag at which balance_readers.pl hits the minimum weight');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_lag_weight_min','0.1','The minimum weight to multiply a reader DB\'s base weight by once its lag hits dbs_reader_lag_secs_end');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_weight_reduce_max','2.0','The maximum number of units per minute to reduce weight down to the minimum');
INSERT INTO vars (name, value, description) VALUES ('dbs_reader_weight_increase_max','1.0','The maximum number of units per minute to restore weight back up to 1');
INSERT INTO vars (name, value, description) VALUES ('dbs_revive_seconds','30','After a DB goes from isalive=no to yes, ramp up accesses to it over how many seconds?');
INSERT INTO vars (name, value, description) VALUES ('debug_db_cache','0','If set, then write debug info for the Slash::DB cache to STDERR');
INSERT INTO vars (name, value, description) VALUES ('debug_maintable_border','0','Border on the main table (for debugging purposes)');
INSERT INTO vars (name, value, description) VALUES ('debughash_getSkins','','false = no debugging; default regex = ^\d+$');
INSERT INTO vars (name, value, description) VALUES ('debughash_getTopicTree','','false = no debugging; default regex = ^\d+$');
INSERT INTO vars (name, value, description) VALUES ('default_maxcommentsize','4096','Default user pref value, if you change the schema default for users_comments.maxcommentsize, change this too');
INSERT INTO vars (name, value, description) VALUES ('default_rss_template','default','name of default rss template used by portald');
INSERT INTO vars (name, value, description) VALUES ('default_skin','chillax','Default skin to use in-case the user has not selected one');
INSERT INTO vars (name, value, description) VALUES ('defaultbytelimit', 5, 'The default setting for comment bytelimit');
INSERT INTO vars (name, value, description) VALUES ('defaultcommentstatus','enabled','default code for article comments- normally "enabled"');
INSERT INTO vars (name, value, description) VALUES ('defaultdisplaystatus','0','Default display status ...');
INSERT INTO vars (name, value, description) VALUES ('defaultsection','articles','Default section to display');
INSERT INTO vars (name, value, description) VALUES ('defaulttopic','1','Default topic to use');
INSERT INTO vars (name, value, description) VALUES ('delayed_inserts_off','1','This turns off delayed inserts (which you probably want to do)');
INSERT INTO vars (name, value, description) VALUES ('delete_old_stories', '0', 'Delete stories and discussions that are older than the archive delay.');
INSERT INTO vars (name, value, description) VALUES ('discussion_approval', '0', 'If this is set to 1, set all user created discussions when created to 0 so that they must be approved');
INSERT INTO vars (name, value, description) VALUES ('discussion_archive_delay','14','days to wait until disabing further comments, set to 0 to disable');
INSERT INTO vars (name, value, description) VALUES ('discussion_create_seclev','1','Seclev required to create discussions (yes, this could be an ACL in the future).');
INSERT INTO vars (name, value, description) VALUES ('discussion_default_topic', '1', 'Default topic of user-created discussions.');
INSERT INTO vars (name, value, description) VALUES ('discussion_display_limit', '30', 'Number of default discussions to list.');
INSERT INTO vars (name, value, description) VALUES ('discussion_skip_dkids', '3', 'discussion types to NOT archive, comma-separated, 3 is Journals');
INSERT INTO vars (name, value, description) VALUES ('discussions_speed_limit','300','seconds delay before repeat discussion');
INSERT INTO vars (name, value, description) VALUES ('do_expiry','0','Flag which controls whether we expire users.');
INSERT INTO vars (name, value, description) VALUES ('down_moderations','-6','number of how many comments you can post that get down moderated');
INSERT INTO vars (name, value, description) VALUES ('draconian_charrefs','0','Enable strictest-possible rules for disallowing HTML entities/character references?');
INSERT INTO vars (name, value, description) VALUES ('draconian_charset','1','Convert high-bit characters to character references, which are then filtered by approveCharrefs or encode_html_amp (works only with Latin-1 for now)');
INSERT INTO vars (name, value, description) VALUES ('draconian_charset_convert','0','Convert some of high-bit chars to ASCII representations instead (see draconian_charset)');
INSERT INTO vars (name, value, description) VALUES ('email_domains_invalid', 'example.com', 'space separated list of domains that are not valid for email addresses');
INSERT INTO vars (name, value, description) VALUES ('enable_index_topic','','set this to the value in string param for index topic \(something like "topic_4"\)');
INSERT INTO vars (name, value, description) VALUES ('enable_portscan','0','Enable portscanning of proxys');
INSERT INTO vars (name, value, description) VALUES ('fancyboxwidth','200','What size should the boxes be in?');
INSERT INTO vars (name, value, description) VALUES ('feature_story_enabled','0','Simple Boolean to determine if homepage prints feature story');
INSERT INTO vars (name, value, description) VALUES ('feed_types', 'rss|atom', 'Feed types allowed.');
INSERT INTO vars (name, value, description) VALUES ('formkey_timeframe','14400','The time frame that we check for a formkey');
INSERT INTO vars (name, value, description) VALUES ('formkey_timeframe_anon','14400','The time frame that we check for a formkey for anon users');
INSERT INTO vars (name, value, description) VALUES ('formkey_minloggedinkarma','1','The min karma a user must have to "count" as a logged-in user for some purposes');
INSERT INTO vars (name, value, description) VALUES ('freshenup_text_render_daysback','7','Oldest stories to write a story_text.rendered field for, in days');
INSERT INTO vars (name, value, description) VALUES ('freshenup_max_stories','100','Maximum number of article.shtml files to write at a time in freshenup.pl');
INSERT INTO vars (name, value, description) VALUES ('freshenup_small_cc','30','How many comments is considered a small commentcount, indicating a story needs its commentcount updated frequently?');
INSERT INTO vars (name, value, description) VALUES ('freshen_homepage_min_minutes','60','Number of minutes between updating the main index.shtml homepage (if 0, disabled, only updates when freshenup.pl believes it is required)');
INSERT INTO vars (name, value, description) VALUES ('goodkarma','25','Users get bonus points for posts if karma above this value');
INSERT INTO vars (name, value, description) VALUES ('gse_precache_mins_ahead','2','How many minutes ahead to precache getStoriesEssentials data in the query cache and memcached?');
INSERT INTO vars (name, value, description) VALUES ('gse_skip_count_if_no_min_stoid', '0', 'If no min_stoid is available, skip counting the s_t_r rows and go straight to the one-table select? Rule of thumb, set this to true for sites with many stories (say, over 10,000)');
INSERT INTO vars (name, value, description) VALUES ('gse_table_join_row_cutoff', '1000', 'Number of stoids below which getStoriesEssentials performs 2 separate selects and above which it performs a JOIN');
INSERT INTO vars (name, value, description) VALUES ("gse_mp_max_days_back", "0", "Max days back to go in gSE select for mainpage in instances where we haven't passed an offset / issue -- 0 if you don't want to use this");
INSERT INTO vars (name, value, description) VALUES ("gse_fallback_min_stoid", "0", "Set by set_gse_min_stoid to define how far back to search max when not passing an issue or offset");
INSERT INTO vars (name, value, description) VALUES ('http_proxy','','http://proxy.www.example.com');
INSERT INTO vars (name, value, description) VALUES ('id_md5_vislength','5','Num chars to display for ipid/subnetid (0 for all)');
INSERT INTO vars (name, value, description) VALUES ('ignore_uid_date_index', '1', 'Ignore uid_date index on comments where it may slow performance');
INSERT INTO vars (name, value, description) VALUES ('imagedir','//www.example.com/images','Absolute URL for image directory');
INSERT INTO vars (name, value, description) VALUES ('imagemagick_convert', '/usr/bin/convert', 'Location of imagemagick convert for thumbnail generation');
INSERT INTO vars (name, value, description) VALUES ('index_gse_backup_prob','0','Probability that index.pl getStoriesEssentials will look to backup_db_user instead of the main db: 0=never, 1=always');
INSERT INTO vars (name, value, description) VALUES ('index_handler','index.pl','The perl servlet to call for connections to the root of the server.');
INSERT INTO vars (name, value, description) VALUES ('index_handler_noanon','home','The shtml page to call if a user is anon and index_noanon is set');
INSERT INTO vars (name, value, description) VALUES ('index_new_user_beta', '0', 'Use index beta for new users?');
INSERT INTO vars (name, value, description) VALUES ('index_noanon','0','Redirect all anonymous users to index_handler_noanon instead of index.shtml. Set to 1 to activate, 0 to remove.');
INSERT INTO vars (name, value, description) VALUES ('index_readmore_with_bytes', '0', 'Include bytes / word count in readmore link where applicable?');
INSERT INTO vars (name, value, description) VALUES ('ircslash','0','Enable the ircslash task and connect to an IRC channel whenever slashd starts');
INSERT INTO vars (name, value, description) VALUES ('ircslash_channel','#ircslash','Which channel to join');
INSERT INTO vars (name, value, description) VALUES ('ircslash_channel_password','','Password for ircslash_channel');
INSERT INTO vars (name, value, description) VALUES ('ircslash_dbalert_bogthresh','30','Alert the IRC channel when DB query bog exceeds this value, in seconds, for the last minute average');
INSERT INTO vars (name, value, description) VALUES ('ircslash_dbalert_lagthresh','30','Alert the IRC channel when DB replication lag exceeds this value, in seconds, for the last minute average');
INSERT INTO vars (name, value, description) VALUES ('ircslash_ircname','','Name to use on IRC server (defaults to "(slashsite) slashd")');
INSERT INTO vars (name, value, description) VALUES ('ircslash_jabber_users','','Pipe-separated list of userids ("userid" or "userid/resource") to send Jabber messages to, instead of sending to channel');
INSERT INTO vars (name, value, description) VALUES ('ircslash_lastremarkid','','Id of the last remark seen');
INSERT INTO vars (name, value, description) VALUES ('ircslash_lcr_sites','','Pipe-separated list of site names to use for lcr cmd');
INSERT INTO vars (name, value, description) VALUES ('ircslash_nick','','Nick to use on IRC server (has a reasonable default)');
INSERT INTO vars (name, value, description) VALUES ('ircslash_port','6667','Port to use on IRC server');
INSERT INTO vars (name, value, description) VALUES ('ircslash_remarks_delay','5','How often, in seconds, to poll for new remarks');
INSERT INTO vars (name, value, description) VALUES ('ircslash_remarks_max_day','10','How many remarks a single user can send, in a day, before we start ignoring them');
INSERT INTO vars (name, value, description) VALUES ('ircslash_remarks_max_month','20','How many remarks a single user can send, in a month, before we start ignoring them');
INSERT INTO vars (name, value, description) VALUES ('ircslash_remarks_max_year','100','How many remarks a single user can send, in a year, before we start ignoring them');
INSERT INTO vars (name, value, description) VALUES ('ircslash_server','irc.slashnet.org','Which IRC server to connect to');
INSERT INTO vars (name, value, description) VALUES ('ircslash_ssl','0','Try to connect over SSL?');
INSERT INTO vars (name, value, description) VALUES ('ircslash_username','','Username to use on IRC server (has a reasonable default)');
INSERT INTO vars (name, value, description) VALUES ('issue_lookback_days','90','Number of days to look back in issue mode');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_ip','4','Downmods at which an IP is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_subnet','6','Downmods at which a subnet is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_user','4','Downmods at which a user is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_max_halflives', '3', 'Max number of times to cut the TrollModval impact of a downmod in half');
INSERT INTO vars (name, value, description) VALUES ('istroll_ipid_hours','72','Hours back that getIsTroll checks IPs for comment mods');
INSERT INTO vars (name, value, description) VALUES ('istroll_uid_hours','72','Hours back that getIsTroll checks uids for comment mods');
INSERT INTO vars (name, value, description) VALUES ('jabberslash','0','Enable the ircslash task for Jabber, and connect to a Jabber channel whenever slashd starts');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_channel','jabberslash','Which channel to join');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_channel_password','','Password for jabberslash_channel');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_channel_server','jabberslash','Which Jabber server to use for the channel (defaults to jabberslash_server)');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_ircname','','Account name to use on Jabber server (defaults to "(slashsite) slashd")');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_nick','','Nick to use on IRC server (has a reasonable default); is used for jabber Resource and channel alias');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_password','','Password for jabberslash_ircname account');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_port','5222','Port to use on Jabber server');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_server','jabber.org','Which Jabber server to connect to');
INSERT INTO vars (name, value, description) VALUES ('jabberslash_tls','0','Try to connect using TLS?');
INSERT INTO vars (name, value, description) VALUES ('karma_adj','-10=Terrible|-1=Bad|0=Neutral|12=Positive|25=Good|99999=Excellent','Adjectives that describe karma, used if karma_obfuscate is set (best to keep aligned with badkarma, m2_maxbonus_karma, and goodkarma)');
INSERT INTO vars (name, value, description) VALUES ('karma_obfuscate','0','Should users see, not their numeric karma score, but instead an adjective describing their approximate karma?');
INSERT INTO vars (name, value, description) VALUES ('karma_posting_penalty_style', '0', '0=old (starting score decremented), 1=new (display score shown lower, comment can suffer results of additional downvotes)');
INSERT INTO vars (name, value, description) VALUES ('label_ui','0','Whether to label some things in the admin ui');
INSERT INTO vars (name, value, description) VALUES ('lastlookmemory','3600','Amount of time the uid last looked-at will be remembered/displayed');
INSERT INTO vars (name, value, description) VALUES ('lastComments','0','Last time we checked comments for moderation points');
INSERT INTO vars (name, value, description) VALUES ('lastsrandsec','awards','Last Block used in the semi-random block');
INSERT INTO vars (name, value, description) VALUES ('lenient_formkeys','0','0 - only ipid, 1 - ipid OR subnetid, in formkey validation check');
INSERT INTO vars (name, value, description) VALUES ('log_admin','1','This turns on/off entries to the accesslog. If you are a small site and want a true number for your stats turn this off.');
INSERT INTO vars (name, value, description) VALUES ('log_db_user','','The virtual user of the database that the code should write accesslog to. If you don\'t know what this is for, you should leave it blank.');
INSERT INTO vars (name, value, description) VALUES ('logdir','/usr/local/slash/www.example.com/logs','Where should the logs be found?');
INSERT INTO vars (name, value, description) VALUES ('logdir_flock','1','flock(LOCK_EX) around appends to log files in logdir?');
INSERT INTO vars (name, value, description) VALUES ('login_nontemp_days', '365', 'Days before a nontemp login expires');
INSERT INTO vars (name, value, description) VALUES ('login_speed_limit', '20', 'How fast a user can create users, etc.');
INSERT INTO vars (name, value, description) VALUES ('login_temp_minutes', '10', 'Minutes before a temporary login expires');
INSERT INTO vars (name, value, description) VALUES ('mailfrom','admin@example.com','All mail addressed from the site looks like it is coming from here');
INSERT INTO vars (name, value, description) VALUES ('mailpass_max_hours','48','Mailing a password only allowed mailpass_max_num times per account per this many hours');
INSERT INTO vars (name, value, description) VALUES ('mailpass_max_num','2','Mailing a password only allowed this many times per account per mainpass_max_hours hours');
INSERT INTO vars (name, value, description) VALUES ('mailpass_valid_days','3','A mailed newpasswd is expired after this many days');
INSERT INTO vars (name, value, description) VALUES ('mainfontface','verdana,helvetica,arial','Fonts');
INSERT INTO vars (name, value, description) VALUES ('mainpage_displayable_nexuses', '', 'List of nexuses that can appear on the mainpage depending on settings; if empty, getStorypickableNexusChildren is used instead');
INSERT INTO vars (name, value, description) VALUES ('mainpage_skid','1','ID of the skin considered "mainpage", the front page, what used to be meant by "always display"');
INSERT INTO vars (name, value, description) VALUES ('mainpage_nexus_tid','1','Topic ID of the nexus considered "mainpage", the front page, what used to be meant by "always display" -- this should be determinable from mainpage_skid but for now it is a separate var');
INSERT INTO vars (name, value, description) VALUES ('markup_checked_attribute',' CHECKED','The checked attribute that is used on the "input" HTML element, CHECKED for HTML 3.2 and checked="checked" for HTML 4.0 and beyond. Must include leading space!');
INSERT INTO vars (name, value, description) VALUES ('max_comments_allowed','30','maximum number of posts per day allowed');
INSERT INTO vars (name, value, description) VALUES ('max_comments_unusedfk','10','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_depth','7','max depth for nesting of comments');
INSERT INTO vars (name, value, description) VALUES ('max_discussions_allowed','3','maximum number of posts per day allowed');
INSERT INTO vars (name, value, description) VALUES ('max_discussions_unusedfk','10','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_expiry_comm','250','Largest value for comment expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('max_expiry_days','365','Largest value for duration expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('max_login_allowed', '10', 'How many forms a user can submit');
INSERT INTO vars (name, value, description) VALUES ('max_submission_size','32000','max size of submission before warning message is displayed');
INSERT INTO vars (name, value, description) VALUES ('max_submissions_allowed','20','maximum number of submissions per timeframe allowed');
INSERT INTO vars (name, value, description) VALUES ('max_submissions_unusedfk','10','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_users_allowed','50','How many changes a user can submit');
INSERT INTO vars (name, value, description) VALUES ('max_users_unusedfk','30','How many unused formkeys are permitted');
INSERT INTO vars (name, value, description) VALUES ('max_users_viewings','30','how many times users.pl can be viewed');
INSERT INTO vars (name, value, description) VALUES ('maxkarma','50','Maximum karma a user can accumulate');
INSERT INTO vars (name, value, description) VALUES ('maxpoints','5','The maximum number of points any moderator can have');
INSERT INTO vars (name, value, description) VALUES ('maxtokens','40','Token threshold that must be hit to get any points');
INSERT INTO vars (name, value, description) VALUES ('maxtokens_add','3','Max tokens to give any one user per pass');
INSERT INTO vars (name, value, description) VALUES ('memcached','0','Use memcached?');
INSERT INTO vars (name, value, description) VALUES ('memcached_debug','0','Turn on debugging for memcached?');
INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_story','600','Number of seconds a story record lives in memcached before requiring a re-read from the DB');
INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_user','1200','Number of seconds a user record lives in memcached before requiring a re-read from the DB (empty string=default, 0=forever)');
INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_comtext','86400','Number of seconds comment text lives in memcached before requiring a re-read from the DB (empty string=default, 0=forever)');
INSERT INTO vars (name, value, description) VALUES ('memcached_keyprefix','x','Unique, short (1-2 chars probably) prefix to distinguish this site from the other sites sharing memcaches');
INSERT INTO vars (name, value, description) VALUES ('memcached_servers','127.0.0.1:11211','Space-sep list of servers for memcached in host:port format; to weight a server append =n');
INSERT INTO vars (name, value, description) VALUES ('min_expiry_comm','10','Lowest value for comment expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('min_expiry_days','7','Lowest value for duration expiry trigger.');
INSERT INTO vars (name, value, description) VALUES ('minkarma','-25','Minimum karma a user can sink to');
INSERT INTO vars (name, value, description) VALUES ('mod_elig_minkarma','0','The min M1 karma');
INSERT INTO vars (name, value, description) VALUES ('mod_karma_bonus_max_downmods',2,'How many times can you downmod a comment without it losing its karma bonus? (bonus lost at value+1th downmod) (set very high to disable)');
INSERT INTO vars (name, value, description) VALUES ('mod_same_subnet_forbid','1','Forbid users from moderating any comments posted by someone in their subnet?');
INSERT INTO vars (name, value, description) VALUES ('mod_stir_recycle_fraction', '1.0', 'What fraction of unused mod points get recycled back into the system?');
INSERT INTO vars (name, value, description) VALUES ('mod_stir_token_cost','2','What is the token cost of having each mod point stirred?');
INSERT INTO vars (name, value, description) VALUES ('mod_token_decay_days','14','How many days of inactivity before tokens start to decay?');
INSERT INTO vars (name, value, description) VALUES ('mod_token_decay_perday','1','If inactivity, how many tokens lost per day?');
INSERT INTO vars (name, value, description) VALUES ('mod_token_assignment_delay', '2', 'Pause in seconds between batches of assigning token changes');
INSERT INTO vars (name, value, description) VALUES ('mod_unm2able_token_cost','1','What is the token cost of performing an un-M2able mod?');
INSERT INTO vars (name, value, description) VALUES ('mod_up_points_needed','','Need more than 1 point to mod up? Hash');
INSERT INTO vars (name, value, description) VALUES ('moderate_or_post', '1', 'Can users moderate and post in the same discussion (1=yes, 0=no)');
INSERT INTO vars (name, value, description) VALUES ('moderatord_catchup_count','2','The number of times moderatord will loop if replication is used and is too far behind our threshold.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_catchup_sleep','2','The number of seconds moderatord will wait each time it loops if replication is behind.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_debug_info', '1', 'Add in more detailed information into slashd.log for moderation task info. This WILL increase the size by slashd.log quite a bit, so use only if you need to.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_lag_threshold','100000','The number of updates replication must be within before moderatord will run using the replicated handle. If this threshold isn\'t met, moderatord will not run.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_lastmaxid', '0', 'Last accesslog.id seen by run_moderatord');
INSERT INTO vars (name, value, description) VALUES ('moderatord_maxrows', '50000', 'Max number of accesslog rows to process at once in run_moderatord');
INSERT INTO vars (name, value, description) VALUES ('modviewseclev','100','Minimum seclev to see moderation totals on a comment');
INSERT INTO vars (name, value, description) VALUES ('nesting_maxdepth','3','Maximum depth to which <BLOCKQUOTE>-type tags can be nested');
INSERT INTO vars (name, value, description) VALUES ('nest_su_maxdepth','1','Maximum depth to which <SUP> and <SUB> tags can be nested');
INSERT INTO vars (name, value, description) VALUES ('newsletter_body','0','Print bodytext, not merely introtext, in newsletter.');
INSERT INTO vars (name, value, description) VALUES ('newsletter_by_default','0','Turn on newsletter sending by default for new users. 0 = off | 1 = on');
INSERT INTO vars (name, value, description) VALUES ('nick_chars', ' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$_.+!*\'(),-', 'Characters allowed in user nicknames');
INSERT INTO vars (name, value, description) VALUES ('nick_regex', '^[a-zA-Z_][ a-zA-Z0-9$_.+!*\'(),-]{0,34}$', 'Regex (case-sensitive) allowed for user nicknames');
INSERT INTO vars (name, value, description) VALUES ('nick_maxlen', '35', 'Max length of nickname, should correspond with schema for users.nickname');
INSERT INTO vars (name, value, description) VALUES ('no_prerendered_stories','0','Turn off use of prerendered stories in display');
INSERT INTO vars (name, value, description) VALUES ('offer_insecure_login_link','0','Offer the user the \'totally insecure but very convenient\' index.pl login link');
INSERT INTO vars (name, value, description) VALUES ('openid_consumer_allow', '1', 'Allow users to authenticate using OpenID, and manage OpenID identities.');
INSERT INTO vars (name, value, description) VALUES ('openid_consumer_secret', rand(), 'Consumer secret for OpenID');
INSERT INTO vars (name, value, description) VALUES ('optipng', '', 'path to optipng if it is to be used for compressing thumbnails');
INSERT INTO vars (name, value, description) VALUES ('organise_stories','','organise story blocks');
INSERT INTO vars (name, value, description) VALUES ('panic','0','0:Normal, 1:No frills, 2:Essentials only');
INSERT INTO vars (name, value, description) VALUES ('poll_cache','0','On home page, cache and display default poll for users (if false, is extra hits to database)');
INSERT INTO vars (name, value, description) VALUES ('poll_discussions','1','Allow discussions on polls');
INSERT INTO vars (name, value, description) VALUES ('poll_dynamic','1','On home page, display dynamic poll on each nexus (if ture, is extra hits to database)');
INSERT INTO vars (name, value, description) VALUES ('poll_fwdfor','1','Loose proxy management for voting?');
INSERT INTO vars (name, value, description) VALUES ('postedout_end_secs','21600','Window to count posted-out stories closes this many seconds in the future');
INSERT INTO vars (name, value, description) VALUES ('postedout_start_secs','300','Window to count posted-out stories opens this many seconds in the future');
INSERT INTO vars (name, value, description) VALUES ('postedout_thisnexusonly','0','If nonzero, only count posted-out stories that are rendered in this nexus, otherwise count all');
INSERT INTO vars (name, value, description) VALUES ('postedout_wanted','2','Number of posted-out stories considered a satisfying normal amount');
INSERT INTO vars (name, value, description) VALUES ('rdfencoding','ISO-8859-1','Site encoding');
INSERT INTO vars (name, value, description) VALUES ('rdfimg','http://www.example.com/images/topics/topicslash.gif','site icon to be used by RSS subscribers');
INSERT INTO vars (name, value, description) VALUES ('rdfitemdesc','0','1 == include introtext in item description; 0 == don\'t.  Any other number is substr() of introtext to use');
INSERT INTO vars (name, value, description) VALUES ('rdfitemdesc_html','0','1 == include HTML in item description; 0 == strip HTML (plain text only)');
INSERT INTO vars (name, value, description) VALUES ('rdflanguage','en-us','What language is the site in?');
INSERT INTO vars (name, value, description) VALUES ('rdfpublisher','Me','The \"publisher\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfrights','Copyright &copy; 2000, Me','The \"copyright\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfsubject','Technology','The \"subject\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfupdatebase','1970-01-01T00:00+00:00','The date to use as a base for the updating');
INSERT INTO vars (name, value, description) VALUES ('rdfupdatefrequency','1','How often to update per rdfupdateperiod');
INSERT INTO vars (name, value, description) VALUES ('rdfupdateperiod','hourly','When to update');
INSERT INTO vars (name, value, description) VALUES ('recent_topic_img_count','5','Number of recent topics to store in the template "recentTopics"');
INSERT INTO vars (name, value, description) VALUES ('recent_topic_txt_count','5','Number of recent topics to store in the block "recenttopics"');
INSERT INTO vars (name, value, description) VALUES ('referrer_external_static_redirect','1','If true, redirect anon requests referred from other sites for dynamic article.pl to static .shtml. This can greatly improve chances of surviving a slashdotting');
INSERT INTO vars (name, value, description) VALUES ('returnto_passwd',CONCAT('changeme',RAND()),'Password used to sign MD5s for returnto URLs from remote sites');
INSERT INTO vars (name, value, description) VALUES ('rootdir','//www.example.com','Base URL of site; used for creating on-site links that need protocol-inspecific URL (so site can be used via HTTP and HTTPS at the same time)');
INSERT INTO vars (name, value, description) VALUES ('rss_allow_index', '0', 'Allow RSS feeds to be served from index.pl (1 = admins, 2 = subscribers, 3 = all logged-in users, 4 = anonymous connections)');
INSERT INTO vars (name, value, description) VALUES ('rss_expire_days','7','Number of days till we blank the data from the database (the signatures still stick around though)');
INSERT INTO vars (name, value, description) VALUES ('rss_max_items_incoming','15','Max number of rss items shown in a slashbox, by default');
INSERT INTO vars (name, value, description) VALUES ('rss_max_items_outgoing','10','Max number of rss items emitted in an rss/rdf/atom feed');
INSERT INTO vars (name, value, description) VALUES ('rss_store','0','Should we be saving incoming submissions for rss');
INSERT INTO vars (name, value, description) VALUES ('run_ads','0','Should we be running ads?');
INSERT INTO vars (name, value, description) VALUES ('runtask_verbosity','3','How much information runtask should write to slashd.log: 0-3 or empty string to use slashd_verbosity');
INSERT INTO vars (name, value, description) VALUES ('sbindir','/usr/local/slash/sbin','Where are the sbin scripts kept');
INSERT INTO vars (name, value, description) VALUES ('search_google','0','Turn on to disable local search (and invite users to use google.com)');
INSERT INTO vars (name, value, description) VALUES ("search_ignore_skids", "", "list of skids that you want to not include in search results.  Delimit skids with |");
INSERT INTO vars (name, value, description) VALUES ('section','index','This is the current setting for section.');
INSERT INTO vars (name, value, description) VALUES ('send_mail','1','Turn On/Off to allow the system to send email messages.');
INSERT INTO vars (name, value, description) VALUES ("signoff_notify", "0", "Add remark for bot on each signoff / update / save ?");
INSERT INTO vars (name, value, description) VALUES ("signoff_use", "0", "Use signoff functionalilty?");
INSERT INTO vars (name, value, description) VALUES ('signoffs_per_article','2','Signoffs Required Per Variable');
INSERT INTO vars (name, value, description) VALUES ('siteadmin','admin','The admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteadmin_name','Slash Admin','The pretty name for the admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteid','www.example.com','The unique ID for this site');
INSERT INTO vars (name, value, description) VALUES ('sitename','Slash Site','Name of the site');
INSERT INTO vars (name, value, description) VALUES ('sitepublisher','Me','The entity that publishes the site');
INSERT INTO vars (name, value, description) VALUES ('slashbox_sections','0','Allow used-selected slashboxes in sections');
INSERT INTO vars (name, value, description) VALUES ('slashbox_whatsplaying','0','Whether or not to turn on the "What\'s Playing" Slashbox.');
INSERT INTO vars (name, value, description) VALUES ('slashboxes_maxnum','25','Maximum number of slashboxes to allow');
INSERT INTO vars (name, value, description) VALUES ('slashd_errnote_lastrun','','Last time slashd_errnote ran');
INSERT INTO vars (name, value, description) VALUES ('slashd_hostname_default','','Hostname of the machine that slashd tasks run on unless otherwise specified in slashd_status.hostname - blank means slashd runs normally anywhere');
INSERT INTO vars (name, value, description) VALUES ('slashd_verbosity','2','How much information slashd (and runtask) should write to slashd.log: 0-3, 3 can be a lot');
INSERT INTO vars (name, value, description) VALUES ('slashdir','/usr/local/slash','Directory where Slash was installed');
INSERT INTO vars (name, value, description) VALUES ('slogan','Slash Site','Slogan of the site');
INSERT INTO vars (name, value, description) VALUES ('smalldevices_ua_regex', 'iPhone', 'regex of user agents for small devices');
INSERT INTO vars (name, value, description) VALUES ('smtp_server','localhost','The mailserver for the site');
INSERT INTO vars (name, value, description) VALUES ('stats_reports','admin@example.com','Who to send daily stats reports to');
INSERT INTO vars (name, value, description) VALUES ('stats_sfnet_groupids','4421','List of sf.net group IDs to keep stats on');
INSERT INTO vars (name, value, description) VALUES ('stem_uncommon_words', '1', 'Use stems of words for detecting similar stories instead of whole words?');
INSERT INTO vars (name, value, description) VALUES ('stir','3','Number of days before unused moderator points expire');
INSERT INTO vars (name, value, description) VALUES ('story_expire','600','Default expiration time for story cache');
INSERT INTO vars (name, value, description) VALUES ('story_never_topic_allow','0','Allow story_never_topic data to be edited and passed to getStoriesEssentials? 0=no, 1=subscriber-only, 2=yes');
INSERT INTO vars (name, value, description) VALUES ('submiss_ts','1','print timestamp in submissions view');
INSERT INTO vars (name, value, description) VALUES ('submiss_view','1','allow users to view submissions queue');
INSERT INTO vars (name, value, description) VALUES ('submission_bonus','3','Bonus given to user if submission is used');
INSERT INTO vars (name, value, description) VALUES ('submission_count_days','60','Number of days back to count submissions made by the same UID or domain');
INSERT INTO vars (name, value, description) VALUES ('submission_default_skid', '0', 'Skid you would like selected by default for submissions, 0 or empty string for none');
INSERT INTO vars (name, value, description) VALUES ('submission_force_default', '0', 'Force selection of default skid for all submissions, takes away menu of options');
INSERT INTO vars (name, value, description) VALUES ('submissions_speed_limit','300','How fast they can submit');
INSERT INTO vars (name, value, description) VALUES ('submit_domains_invalid', 'example.com', 'space separated list of domains that are not valid for submitting stories');
INSERT INTO vars (name, value, description) VALUES ('submit_categories','Back','Extra submissions categories');
INSERT INTO vars (name, value, description) VALUES ('submit_extra_sort_key', '', 'Provides an additional submission list sorted on the given field name');
INSERT INTO vars (name, value, description) VALUES ('submit_keep_p',1,'Keep <p> tags in story submissions');
INSERT INTO vars (name, value, description) VALUES ('submit_forgetip_hours','720','Hours after which a submissions\'s ipid/subnetid are forgotten; set very large to disable');
INSERT INTO vars (name, value, description) VALUES ('submit_forgetip_maxrows','100000','Max number of rows to forget IPs of at once');
INSERT INTO vars (name, value, description) VALUES ('submit_forgetip_minsubid','0','Minimum subid to start forgetting IP at');
INSERT INTO vars (name, value, description) VALUES ('submit_show_weight', '0', 'Display optional weight field in submission admin.');
INSERT INTO vars (name, value, description) VALUES ('subnet_karma_comments_needed','5','Number of comments needed before subnet karma is used for disallowing posting');
INSERT INTO vars (name, value, description) VALUES ('subnet_karma_post_limit_range','-5|-9|-10|-999999','range of subnet karma to block posting at -5|-9|-10|-999999 blocks anonymous posting at -5 to -9 subnet karma, and all posting from -10 to -999999 subnet karma');
INSERT INTO vars (name, value, description) VALUES ('subs_level','15','Level at which to not to display low submissions message, set to 0 to disable message');
INSERT INTO vars (name, value, description) VALUES ('task_timespec_freshenup', '* * * * *', 'Custom timespec (in cron style) for the freshenup task. Add more task_timespec_ vars if you want to override other task timespecs.');
INSERT INTO vars (name, value, description) VALUES ('template_cache_request','0','Special boolean to cache templates only for a single request');
INSERT INTO vars (name, value, description) VALUES ('template_cache_size','0','Number of templates to store in cache (0 = unlimited)');
INSERT INTO vars (name, value, description) VALUES ('template_post_chomp','0','Chomp whitespace after directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_pre_chomp','0','Chomp whitespace before directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_show_comments', '1', 'Show HTML comments before and after template? (see Slash::Display) 0=no 1=yes unless Nocomm 2=ALWAYS (debugging only!)');
INSERT INTO vars (name, value, description) VALUES ('textarea_cols', '50', 'Default # of columns for content TEXTAREA boxes');
INSERT INTO vars (name, value, description) VALUES ('textarea_rows', '10', 'Default # of rows for content TEXTAREA boxes');
INSERT INTO vars (name, value, description) VALUES ('tids_in_urls', '0', 'Want tid=1&tid=2 in story and discussion-related URLs?');
INSERT INTO vars (name, value, description) VALUES ('titlebar_width','100%','The width of the titlebar');
INSERT INTO vars (name, value, description) VALUES ('tokenspercomment','6','Number of tokens to feed the system for each comment');
INSERT INTO vars (name, value, description) VALUES ('tokensperpoint','8','Number of tokens per point');
INSERT INTO vars (name, value, description) VALUES ('topcomm_days','1','Look back (n) days to display the Hot Comments slashbox');
INSERT INTO vars (name, value, description) VALUES ('topcomm_num','5','Number of comments wanted for the Hot Comments slashbox. Defaults to 5.');
INSERT INTO vars (name, value, description) VALUES ('top_sid','','The sid of the most recent story on the homepage');
INSERT INTO vars (name, value, description) VALUES ('topiclist_ignore_prefix', '', 'prefix of any topic keywords that should not show up on topic list or hierarchy, leave blank if you don\'t want any ignored');
INSERT INTO vars (name, value, description) VALUES ('totalComments','0','Total number of comments posted');
INSERT INTO vars (name, value, description) VALUES ('totalhits','0','Total number of hits the site has had thus far');
INSERT INTO vars (name, value, description) VALUES ('url_checker_user_agent', '', 'user Agent to use for url checking task, empty string results in lwp user agent being used');
INSERT INTO vars (name, value, description) VALUES ('use_dept','1','use \"dept.\" field');
INSERT INTO vars (name, value, description) VALUES ('use_https_for_absolutedir_secure', '1', 'Should we use https as a secure absolutedir for nexuses (YOU PROBABLY WANT THIS!)');
INSERT INTO vars (name, value, description) VALUES ('use_prev_next_link','1','Boolean where to use next/prev links for articles');
INSERT INTO vars (name, value, description) VALUES ('use_prev_next_link_series','0','Boolean where to use next/prev links for articles in a series (topic)');
INSERT INTO vars (name, value, description) VALUES ('use_prev_next_link_section','0','Boolean where to use next/prev links for articles in a section');
INSERT INTO vars (name, value, description) VALUES ('user_comment_display_default','24','Number of comments to display on user\'s info page');
INSERT INTO vars (name, value, description) VALUES ('user_comments_force_index', '0', 'Give user comments query hint to use specific index?');
INSERT INTO vars (name, value, description) VALUES ('user_submitter_display_default','24','Number of stories to display on user\'s info page');
INSERT INTO vars (name, value, description) VALUES ('users_bio_length','1024','Length allowed for user bio');
INSERT INTO vars (name, value, description) VALUES ('users_count','1','(Approximate) number of users registered on this slash site');
INSERT INTO vars (name, value, description) VALUES ('users_menu_no_display', '0', 'Hide users menu?');
INSERT INTO vars (name, value, description) VALUES ('users_show_info_seclev','0','Minimum seclev to view a user\s info');
INSERT INTO vars (name, value, description) VALUES ('users_speed_limit','20','How fast a user can change their prefs');
INSERT INTO vars (name, value, description) VALUES ('utf8', '1', '1 = Use end-to-end unicode, 0 = Convert unicode to html entities');
INSERT INTO vars (name, value, description) VALUES ('writestatus','dirty','Simple Boolean to determine if homepage needs rewriting');
INSERT INTO vars (name, value, description) VALUES ('xhtml','0','Boolean for whether we are using XHTML');
INSERT INTO vars (name, value, description) VALUES ('days_to_count_for_modpoints', '1', 'Number of days to use in counting comments for handing out modpoints');
INSERT INTO vars (name, value, description) VALUES ('utf8_max_diacritics', '4', 'The threshold of diacritic marks on a single character at which they all get stripped off');
INSERT INTO vars (name, value, description) VALUES ("downmod_karma_floor", "10", "Below this level of karma, users cannot use negative moderations");
INSERT INTO vars (name, value, description) VALUES ("onion_location", "", "Location of the Onion server");