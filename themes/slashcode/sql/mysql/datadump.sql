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

INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('articles_more','',1000,'static',NULL,'articles',5,'Articles',0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('colors','#FFFFFF,#222222,#111111,#DDDDDD,#99DD99,#DDDDDD,#FFFFFF,#DDDDDD,#660000,#AAEEAA',1000,'color','<P>This is a comma delimited list of colors that are split by comma and \r\nassigned to two arrays: $I{fg} and $I{bg}. <BR>The first half of these colors go into $I{fg} and the last half go into $I{bg}.</P>','',0,'',NULL,'','',0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('emailsponsor','Put an advertisement here.  Or make it blank.  See if I care.\r\n\r\n',500,'',NULL,'',0,'',0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('features','<!-- begin features block -->\r\nThis is a place where you can put linkage to important stories\r\nthat you have on your site.  Or else you can just link some porn.\r\nYou can edit this space easily by just logging into backSlash, clicking\r\n\'Blocks\' from the admin menu, and editing the block named \'features\'.\r\n<!-- end features block -->\r\n\r\n',500,'',NULL,'index',1,'Features',1,'index.pl?section=features',NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('features_more','',1000,'static',NULL,'features',5,'more',0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('features_qlinks','<!-- begin quicklinks block -->\n<A HREF=\"http://newsforge.com/\">Newsforge</A><BR>\n<A HREF=\"http://lists.slashdot.org/mailman/listinfo.cgi\">Slash Mailing lists</A><BR>\n<A HREF=\"http://www.slashcode.com/\">Slashcode.com</A><BR>\n<A HREF=\"http://slashdot.org/\">Slashdot</A><BR>\n<A HREF=\"http://andover.net/\">Andover.Net</A><BR>\n<A HREF=\"http://CmdrTaco.net/\">CmdrTaco.net</A><BR>\n<A HREF=\"http://www.cowboyneal.org/\">Cowboyneal.org</A><BR>\n<A HREF=\"http://pudge.net/\">Pudge.Net</A><BR>\n<A HREF=\"http://thinkgeek.com/\">ThinkGeek</A><BR>\n\n<!-- end quicklinks block -->',500,'static',NULL,'features',7,'Quick Links',0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('index_more','',1000,'',NULL,'index',5,'Older Stuff',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('index_qlinks','<!-- begin quicklinks block -->\r\n\r\nYou should put some links here to other sites that your users might enjoy.\r\n\r\n<!-- end quicklinks block -->\r\n\r\n',10000,'',NULL,'index',7,'Quick Links',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('mysite','By editing the section called \"User Space\" on the user\r\npreferences page, you can cause this space to be filled\r\nwith any HTML you specify. Personal URLs?  Your Credit Card\r\nNumbers and Social Security numbers?  Well, maybe you\r\nbetter stick to URLs.\r\n',10000,'',NULL,'index',-10,'User Space',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('poll','<FORM ACTION=\"//www.example.com/pollBooth.pl\">\r\n	<INPUT TYPE=\"hidden\" NAME=\"qid\" VALUE=\"happy\"\r\n<B>Are you happy?</B>\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"1\">No\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"2\">Yes\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"3\">thorazine\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"4\">apathy\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"5\">manic depressive\r\n<BR><INPUT TYPE=\"submit\" VALUE=\"Vote\"> [ <A HREF=\"//www.example.com/pollBooth.pl?qid=happy&aid=-1\"><B>Results</B></A> | <A HREF=\"//www.example.com/pollBooth.pl?\"><B>Polls</B></A>  ] <BR>\r\nComments:<B>0</B> | Votes:<B>43</B>\r\n</FORM>\r\n',1000,'portald',NULL,'index',2,'Poll',1,NULL,NULL,NULL);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('top10comments','',500,'portald','','index',0,'10 Hot Comments',1,'',NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('topics','	<TD><A HREF=\"//www.example.com/search.pl?topic=news\"><IMG\r\n		SRC=\"//www.example.com/images/topics/topicnews.gif\" WIDTH=\"34\" HEIGHT=\"44\"\r\n		BORDER=\"0\" ALT=\"News\"></A>\r\n	</TD>\r\n\r\n	<TD><A HREF=\"//www.example.com/search.pl?topic=slashdot\"><IMG\r\n		SRC=\"//www.example.com/images/topics/topicslashdot.gif\" WIDTH=\"100\" HEIGHT=\"34\"\r\n		BORDER=\"0\" ALT=\"Slashdot\"></A>\r\n	</TD>\r\n\r\n',10000,'static','<P>\r\nThe topics block.\r\n</P>','',0,NULL,0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('userlogin','',1000,'static','','index',4,'Login',1,NULL,NULL,0);


#
# Dumping data for table 'code_param'
#

INSERT INTO code_param (type, code, name) VALUES ('commentcodes',0,'Comments Enabled');
INSERT INTO code_param (type, code, name) VALUES ('commentcodes',1,'Read-Only');
INSERT INTO code_param (type, code, name) VALUES ('commentcodes',-1,'Comments Disabled');
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

INSERT INTO comments (sid, cid, pid, date, host_name, subject, comment, uid, points, lastmod, reason) VALUES ('00/01/25/1430236',1,0,'2000-01-25 15:47:36','208.163.7.213','First Post!','This is the first post put into your newly installed Slash System.  There will be many more.  Many will be intelligent and well written.  Others will be drivel.  And then there will be a bunch of faceless anonymous morons who will attack you for no reason except that they are having a bad day.  But in the end it\'ll hopefully all be worth it, because those intelligent users will exchange useful ideas and hopefully learn something and grow as human beings.  Have fun!',1,0,-1,0);

#
# Dumping data for table 'content_filters'
#

INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('.*first.*post.*','gi','postersubj',0.0000,0,0,'What do you want? A medal?',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(?:\\s+)','gi','postersubj',0.0000,7,0,'Lots of space in the subject ... lots of space in the head.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(?:\\s+)','gi','postercomment',0.0000,40,0,'Lots of space in the comment ... lots of space in the head.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('(?:(?:\\W){5,})','gi','postercomment',0.0000,5,25,'Junk character post.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('(?:\\b(?:[^a-zA-Z0-9])+\\b)','gi','postercomment',0.0000,10,10,'Junk character post.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('(?:\\b(?:[^a-zA-Z0-9])+\\b)','gi','postersubj',0.0000,10,0,'Junk character post.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(.)\\1{5,}$','gi','postersubj',0.0000,0,0,'Junk character post.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(?:.)$','gi','postersubj',0.0000,0,0,'One character. Hmmm. Gee, might this be a troll?',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(?:.)$','gi','postercomment',0.0000,0,0,'One character. Hmmm. Gee, might this be a troll?',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('[\\\\\\,\\.\\-\\_\\*\\|\\}\\{\\]\\[\\@\\&\\%\\$\\s\\)\\(\\?\\!\\^\\=\\+\\~\\`\\\"\\\']','gi','postercomment',0.6000,0,10,'Ascii art. How creative. Not here though.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('[^a-zA-Z0-9]','gi','postercomment',0.6000,0,10,'Ascii Art. How creative. Not here though.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('[^a-zA-Z0-9]','gi','postersubj',0.6000,0,10,'Ascii Art. How creative. Not here though.',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('[^a-z]','g','postercomment',0.5000,0,2,'PLEASE DON\'T USE SO MANY CAPS. USING CAPS IS LIKE YELLING!',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('[^a-z]','g','postersubj',0.5000,0,2,'PLEASE DON\'T USE SO MANY CAPS. USING CAPS IS LIKE YELLING!',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(?:)$','gi','postersubj',0.0000,0,0,'Cat got your tongue? You mean you have nothing to say?',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('^(?:)$','gi','postercomment',0.0000,0,0,'Cat got your tongue? You mean you have nothing to say?',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('\\w{80}','','postersubj',0.0000,0,0,'that\'s an awful long string of letters there!',0);
INSERT INTO content_filters (regex, modifier, field, ratio, minimum_match, minimum_length, err_message, maximum_length) VALUES ('\\w{80}','','postercomment',0.0000,0,0,'that\'s an awful long string of letters there!',0);

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
INSERT INTO dateformats (id, format, description) VALUES (10,'%I:%M %p  %B %E, %Y','10:00 AM  March 21st, 1999');
INSERT INTO dateformats (id, format, description) VALUES (11,'%k:%M  %E %B, %Y','23:00  21st March, 1999');
INSERT INTO dateformats (id, format, description) VALUES (12,'%a %b %d, \'%y %I:%M %p','Sun Mar 21, \'99 10:00 AM');
INSERT INTO dateformats (id, format, description) VALUES (13,'%i ish','6 ish');
INSERT INTO dateformats (id, format, description) VALUES (14,'%y-%m-%d %k:%M','99-03-19 14:14');
INSERT INTO dateformats (id, format, description) VALUES (16,'%a %d %b %I:%M%p','Sun 21 Mar 10:00AM');
INSERT INTO dateformats (id, format, description) VALUES (17,'%Y.%m.%d %k:%M','1999.03.19 14:14');

#
# Dumping data for table 'discussions'
#

INSERT INTO discussions (sid, title, url, ts) VALUES ('00/01/25/1430236','You\'ve Installed Slash!','http://slashcode.com/article.pl?sid=00/01/25/1430236','2000-01-25 14:30:36');
INSERT INTO discussions (sid, title, url, ts) VALUES ('00/01/25/1236215','Now What?','//www.example.com/article.pl?sid=00/01/25/1236215','2000-01-25 17:36:15');

#
# Dumping data for table 'formkeys'
#


#
# Dumping data for table 'hitters'
#


#
# Dumping data for table 'menus'
#

INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','User Info','[% constants.rootdir %]/users.pl',1,1);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','New User','[% constants.rootdir %]/users.pl?op=newuseradmin',10000,2);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Customize Homepage','[% constants.rootdir %]/users.pl?op=edithome',1,3);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Edit User Info','[% constants.rootdir %]/users.pl?op=edituser',1,4);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Customize Comments','[% constants.rootdir %]/users.pl?op=editcomm',1,5);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Logout','[% constants.rootdir %]/users.pl?op=userclose',1,6);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('topics','Recent Topics','[% constants.rootdir %]/topics.pl?op=toptopics',0,1);

#
# Dumping data for table 'metamodlog'
#


#
# Dumping data for table 'moderatorlog'
#


#
# Dumping data for table 'newstories'
#

INSERT INTO newstories (sid, tid, uid, commentcount, title, dept, time, introtext, bodytext, writestatus, hits, section, displaystatus, commentstatus, hitparade, relatedtext, extratext) VALUES ('00/01/25/1236215','slash',2,0,'Now What?','where-do-you-go-from-here','2000-01-25 08:32:02','You should play around with the admin stuff.  Configure things to\r\nyour tastes.  You should also edit the slashdotrc.pl to define things like your websites name and slogan.  You should also donate some money to the <A href=http://www.fsf.org>FSF</A> and <A href=http://slashdot.org>Read Slashdot</A>.\r\n','',0,0,'articles',0,0,'0,0,0,0,0,0,0','<LI><A href=http://www.fsf.org>FSF</A></LI>\n<LI><A href=http://slashdot.org>Read Slashdot</A></LI>\n<LI><A HREF=\"//www.example.com/search.pl?topic=slash\">More on Slash</A></LI>\r\n<LI><A HREF=\"//www.example.com/search.pl?author=God\">Also by God</A></LI>',NULL);
INSERT INTO newstories (sid, tid, uid, commentcount, title, dept, time, introtext, bodytext, writestatus, hits, section, displaystatus, commentstatus, hitparade, relatedtext, extratext) VALUES ('00/01/25/1430236','slash',2,1,'You\'ve Installed Slash!','congratulations-dude','2000-08-28 20:47:46','So it took some doing, but it looks like you\'ve got Slash installed and ready to rock.  You can now login using <A href=/admin.pl>backSlash</A>, the Slash Code Administration tool.  The default account is God and whatever password you set during the install.  And you might wanna start posting some stories too.','',0,0,'articles',0,0,'1,1,1,0,0,0,0','<LI><A href=/admin.pl>backSlash</A></LI>\n<LI><A HREF=\"//www.example.com/search.pl?topic=slash\">More on Slash</A></LI>\r\n<LI><A HREF=\"//www.example.com/search.pl?author=God\">Also by God</A></LI>',NULL);

#
# Dumping data for table 'pollanswers'
#

INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('icecream',1,'Chocolate',3);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('icecream',2,'Vanilla',1);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('icecream',3,'Strawberry',0);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('icecream',4,'Rocky Road',0);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('icecream',5,'Pepto bismol',1);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('happy',1,'No',0);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('happy',2,'Yes',2);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('happy',3,'thorazine',3);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('happy',4,'apathy',1);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES ('happy',5,'manic depressive',1);

#
# Dumping data for table 'pollquestions'
#

INSERT INTO pollquestions (qid, question, voters, date) VALUES ('icecream','what flavor of ice cream?',5,'2000-01-16 19:11:10');
INSERT INTO pollquestions (qid, question, voters, date) VALUES ('happy','Are you happy?',7,'2000-01-19 16:23:00');

#
# Dumping data for table 'pollvoters'
#


#
# Dumping data for table 'sections'
#

INSERT INTO sections (section, artcount, title, qid, isolate, issue, extras) VALUES ('articles',30,'Articles','',0,0,0);
INSERT INTO sections (section, artcount, title, qid, isolate, issue, extras) VALUES ('features',21,'Features','eyesight',0,1,0);
INSERT INTO sections (section, artcount, title, qid, isolate, issue, extras) VALUES ('slash',15,'Slash','firstpost',1,1,0);
INSERT INTO sections (section, artcount, title, qid, isolate, issue, extras) VALUES ('',30,'All Sections','',0,0,0);

#
# Dumping data for table 'sessions'
#


#
# Dumping data for table 'site_info'
#


#
# Dumping data for table 'stories'
#

INSERT INTO stories (sid, tid, uid, commentcount, title, dept, time, introtext, bodytext, writestatus, hits, section, displaystatus, commentstatus, hitparade, relatedtext, extratext) VALUES ('00/01/25/1236215','slash',2,0,'Now What?','where-do-you-go-from-here','2000-01-25 08:32:02','You should play around with the admin stuff.  Configure things to\r\nyour tastes.  You should also edit the variables (in the admin menu) to define things like your websites name and slogan.  You should also donate some money to the <A href=http://www.fsf.org>FSF</A> and <A href=http://slashdot.org>Read Slashdot</A>.\r\n','',1,0,'articles',0,0,'0,0,0,0,0,0,0','<LI><A href=http://www.fsf.org>FSF</A></LI>\n<LI><A href=http://slashdot.org>Read Slashdot</A></LI>\n<LI><A HREF=\"//www.example.com/search.pl?topic=slash\">More on Slash</A></LI>\r\n<LI><A HREF=\"//www.example.com/search.pl?author=God\">Also by God</A></LI>',NULL);
INSERT INTO stories (sid, tid, uid, commentcount, title, dept, time, introtext, bodytext, writestatus, hits, section, displaystatus, commentstatus, hitparade, relatedtext, extratext) VALUES ('00/01/25/1430236','slash',2,1,'You\'ve Installed Slash!','congratulations-dude','2000-08-28 20:47:46','So it took some doing (hopefully not too much), and it looks like you\'ve got Slash installed and ready to rock.  You can now use <A href="/admin.pl">backSlash</A>, the Slash Code Administration tool, if you are logged in as the admin user you set up during installation.  And you might wanna start posting some stories too.','',0,0,'articles',0,0,'1,1,1,0,0,0,0','<LI><A href=/admin.pl>backSlash</A></LI>\n<LI><A HREF=\"//www.example.com/search.pl?topic=slash\">More on Slash</A></LI>\r\n<LI><A HREF=\"//www.example.com/search.pl?author=God\">Also by God</A></LI>',NULL);

#
# Dumping data for table 'storiestuff'
#

INSERT INTO storiestuff (sid, hits) VALUES ('00/01/17/1440252',24);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/14/1737203',5);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/14/1737236',8);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/0035257',1);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/0037255',8);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/0042250',0);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/1133238',1);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/1134204',1);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/1134221',0);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/16/1134241',22);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/25/1430236',36);
INSERT INTO storiestuff (sid, hits) VALUES ('00/01/25/1236215',2);

#
# Dumping data for table 'story_param'
#


#
# Dumping data for table 'submissions'
#

INSERT INTO submissions (subid, email, name, time, subj, story, tid, note, section, comment, uid, del) VALUES ('15258.025100','somewhere@somewhere.com','PostMyStory','2000-01-25 15:25:08','This is the Submissions Area','This is where you read the submissions that your reader send you.  From here you can delete them (click the checkboxes and hit update) or attach little notes to them and flag them to be put on hold, or saved for quickies (all of these things are helpful when you have several people working on the backend at the same time).\r\n\r\n<P>Most of the time you\'ll just want to click on the title of the submission, and then either preview/post it, or delete it. ','topic1',NULL,'articles',NULL,2,0);

#
# Dumping data for table 'templates'
#


#
# Dumping data for table 'topics'
#

INSERT INTO topics (tid, image, alttext, width, height) VALUES ('news','topicnews.gif','News',34,44);
INSERT INTO topics (tid, image, alttext, width, height) VALUES ('linux','topiclinux.gif','Linux',60,70);
INSERT INTO topics (tid, image, alttext, width, height) VALUES ('slashdot','topicslashdot.gif','Slashdot',100,34);
INSERT INTO topics (tid, image, alttext, width, height) VALUES ('slash','topicslash.gif','Slash',81,36);
INSERT INTO topics (tid, image, alttext, width, height) VALUES ('','topicslash.gif','All Topics',81,36);

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
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MET',3600,'Middle European');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('MEW',3600,'Middle European Winter');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('SWT',3600,'Swedish Winter');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('FWT',3600,'French Winter');
INSERT INTO tzcodes (tz, off_set, description) VALUES ('EET',7200,'Eastern Europe, USSR Zone 1');
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

INSERT INTO users (uid, nickname, realemail, fakeemail, homepage, passwd, sig, seclev, matchname, newpasswd) VALUES (1,'Anonymous Coward','','','','','',0,'anonymouscoward',NULL);

#
# Dumping data for table 'users_comments'
#

INSERT INTO users_comments (uid, points, posttype, defaultpoints, highlightthresh, maxcommentsize, hardthresh, clbig, clsmall, reparent, nosigs, commentlimit, commentspill, commentsort, noscores, mode, threshold) VALUES (1,0,2,0,4,4096,0,0,0,1,0,50000,50,0,0,'thread',0);

#
# Dumping data for table 'users_index'
#

INSERT INTO users_index (uid, extid, exaid, exsect, exboxes, maxstories, noboxes) VALUES (1,'','','','',30,0);

#
# Dumping data for table 'users_info'
#

INSERT INTO users_info (uid, totalmods, realname, bio, tokens, lastgranted, karma, maillist, totalcomments, lastmm, lastaccess, lastmmid, m2fair, m2unfair, m2fairvotes, m2unfairvotes, upmods, downmods, session_login) VALUES (1,0,'Anonymous Coward','',0,'0000-00-00',0,0,0,'0000-00-00','0000-00-00',0,0,0,0,0,0,0,0);

#
# Dumping data for table 'users_param'
#


#
# Dumping data for table 'users_prefs'
#

INSERT INTO users_prefs (uid, willing, dfid, tzcode, noicons, light, mylinks) VALUES (1,1,0,'EST',0,0,'');

#
# Dumping data for table 'vars'
#

INSERT INTO vars (name, value, description) VALUES ('absolutedir','http://www.example.com','Absolute base URL of site; used for creating links external to site that need a complete URL');
INSERT INTO vars (name, value, description) VALUES ('adminmail','admin@example.com','All admin mail goes here');
INSERT INTO vars (name, value, description) VALUES ('admin_timeout','30','time in minutes before idle admin session ends');
INSERT INTO vars (name, value, description) VALUES ('allow_anonymous','1','allow anonymous posters');
INSERT INTO vars (name, value, description) VALUES ('anonymous_coward_uid','1','UID to use for anonymous coward');
INSERT INTO vars (name, value, description) VALUES ('approvedtags','B|I|P|A|LI|OL|UL|EM|BR|TT|STRONG|BLOCKQUOTE|DIV','Tags that you can use');
INSERT INTO vars (name, value, description) VALUES ('archive_delay','60','days to wait for story archiving, comments deleting');
INSERT INTO vars (name, value, description) VALUES ('articles_only','0','show only Articles in submission count in admin menu');
INSERT INTO vars (name, value, description) VALUES ('authors_unlimited','1','Authors have unlimited moderation');
INSERT INTO vars (name, value, description) VALUES ('badkarma','-10','Users get penalized for posts if karma is below this value');
INSERT INTO vars (name, value, description) VALUES ('badreasons','4','number of \"Bad\" reasons in \"reasons\", skip 0 (which is neutral)');
INSERT INTO vars (name, value, description) VALUES ('basedir','/usr/local/slash/www.example.com/htdocs','Where should the html/perl files be found?');
INSERT INTO vars (name, value, description) VALUES ('basedomain','www.example.com','The URL for the site');
INSERT INTO vars (name, value, description) VALUES ('block_expire','3600','Default expiration time for the block cache');
INSERT INTO vars (name, value, description) VALUES ('breaking','100','Undefined');
INSERT INTO vars (name, value, description) VALUES ('cache_enabled','1','Simple Boolean to determine if content is cached or not');
INSERT INTO vars (name, value, description) VALUES ('commentsPerPoint','1000','For every X comments, valid users get a Moderator Point');
INSERT INTO vars (name, value, description) VALUES ('commentstatus','0','default comment code');
INSERT INTO vars (name, value, description) VALUES ('comment_maxscore','5','Maximum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_minscore','-1','Minimum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('cookiedomain','','Domain for cookie to be active (normally leave blank)');
INSERT INTO vars (name, value, description) VALUES ('cookiepath','/','Path on server for cookie to be active');
INSERT INTO vars (name, value, description) VALUES ('cookiesecure','0','Whether or not to set secure flag in cookies if SSL is on (not working)');
INSERT INTO vars (name, value, description) VALUES ('currentqid','happy','The Current Question on the homepage pollbooth');
INSERT INTO vars (name, value, description) VALUES ('daily_attime','00:00:00','Time of day to run dailyStuff (in TZ daily_tz; 00:00:00-23:59:59)');
INSERT INTO vars (name, value, description) VALUES ('daily_last','2000-01-01 01:01:01','Last time dailyStuff was run (GMT)');
INSERT INTO vars (name, value, description) VALUES ('daily_tz','EST','Base timezone for running dailyStuff');
INSERT INTO vars (name, value, description) VALUES ('datadir','/usr/local/slash/www.example.com','What is the root of the install for Slash');
INSERT INTO vars (name, value, description) VALUES ('defaultcommentstatus','0','default code for article comments- normally 0=posting allowed');
INSERT INTO vars (name, value, description) VALUES ('defaultdisplaystatus','0','Default display status ...');
INSERT INTO vars (name, value, description) VALUES ('defaultsection','articles','Default section to display');
INSERT INTO vars (name, value, description) VALUES ('defaultwritestatus','1','Default write status for newly created articles');
INSERT INTO vars (name, value, description) VALUES ('down_moderations','-6','number of how many comments you can post that get down moderated');
INSERT INTO vars (name, value, description) VALUES ('fancyboxwidth','200','What size should the boxes be in?');
INSERT INTO vars (name, value, description) VALUES ('formkey_timeframe','14400','The time frame that we check for a formkey');
INSERT INTO vars (name, value, description) VALUES ('goodkarma','25','Users get bonus points for posts if karma above this value');
INSERT INTO vars (name, value, description) VALUES ('http_proxy','','http://proxy.www.example.com');
INSERT INTO vars (name, value, description) VALUES ('imagedir','//www.example.com/images','Absolute URL for image directory');
INSERT INTO vars (name, value, description) VALUES ('lastComments','0','Last time we checked comments for moderation points');
INSERT INTO vars (name, value, description) VALUES ('lastsrandsec','awards','Last Block used in the semi-random block');
INSERT INTO vars (name, value, description) VALUES ('logdir','/usr/local/slash/www.example.com/logs','Where should the logs be found?');
INSERT INTO vars (name, value, description) VALUES ('m2_bonus','+1','Bonus for participating in meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_comments','10','Number of comments for meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_maxbonus','12','Usually 1/2 of goodkarma');
INSERT INTO vars (name, value, description) VALUES ('m2_maxunfair','0.5','Minimum % of unfairs for M2 penalty');
INSERT INTO vars (name, value, description) VALUES ('m2_mincheck','3','Usually 1/3 of m2_comments');
INSERT INTO vars (name, value, description) VALUES ('m2_penalty','-1','Penalty for misuse of meta-moderation');
INSERT INTO vars (name, value, description) VALUES ('m2_toomanyunfair','0.3','Minimum % of unfairs for which M2 is ignored');
INSERT INTO vars (name, value, description) VALUES ('m2_userpercentage','0.9','UID must be below this percentage of the total userbase to metamoderate');
INSERT INTO vars (name, value, description) VALUES ('mailfrom','admin@example.com','All mail addressed from the site looks like it is coming from here');
INSERT INTO vars (name, value, description) VALUES ('mainfontface','verdana,helvetica,arial','Fonts');
INSERT INTO vars (name, value, description) VALUES ('maxkarma','50','Maximum karma a user can accumulate');
INSERT INTO vars (name, value, description) VALUES ('maxpoints','5','The maximum number of points any moderator can have');
INSERT INTO vars (name, value, description) VALUES ('maxtokens','40','Token threshold that must be hit to get any points');
INSERT INTO vars (name, value, description) VALUES ('max_depth','7','max depth for nesting of comments');
INSERT INTO vars (name, value, description) VALUES ('max_posts_allowed','30','maximum number of posts per day allowed');
INSERT INTO vars (name, value, description) VALUES ('max_submissions_allowed','20','maximum number of submissions per timeframe allowed');
INSERT INTO vars (name, value, description) VALUES ('metamod_sum','3','sum of moderations 1 for release (deprecated)');
INSERT INTO vars (name, value, description) VALUES ('poll_cache','0','On home page, cache and display default poll for users (if false, is extra hits to database)');
INSERT INTO vars (name, value, description) VALUES ('post_limit','10','seconds delay before repeat posting');
INSERT INTO vars (name, value, description) VALUES ('rdfencoding','ISO-8859-1','Site encoding');
INSERT INTO vars (name, value, description) VALUES ('rdfimg','http://www.example.com/images/topics/topicslash.gif','Site encoding');
INSERT INTO vars (name, value, description) VALUES ('rdflanguage','en-us','What language is the site in?');
INSERT INTO vars (name, value, description) VALUES ('rdfsubject','Technology','The \"subject\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfpublisher','Me','The \"publisher\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfrights','Copyright &copy; 2000, Me','The \"copyright\" for your RSS channel');
INSERT INTO vars (name, value, description) VALUES ('rdfupdateperiod','hourly','When to update');
INSERT INTO vars (name, value, description) VALUES ('rdfitemdesc','0','1 == include introtext in item description; 0 == don\'t.  Any other number is substr() of introtext to use');
INSERT INTO vars (name, value, description) VALUES ('rdfupdatefrequency','1','How often to update per rdfupdateperiod');
INSERT INTO vars (name, value, description) VALUES ('rdfupdatebase','1970-01-01T00:00+00:00','The date to use as a base for the updating');
INSERT INTO vars (name, value, description) VALUES ('reasons','Normal|Offtopic|Flamebait|Troll|Redundant|Insightful|Interesting|Informative|Funny|Overrated|Underrated','first is neutral, next $badreasons are bad, the last two are \"special\", the rest are good');
INSERT INTO vars (name, value, description) VALUES ('rootdir','//www.example.com','Base URL of site; used for creating on-site links that need protocol-inspecific URL (so site can be used via HTTP and HTTPS at the same time)');
INSERT INTO vars (name, value, description) VALUES ('run_ads','0','Should we be running ads?');
INSERT INTO vars (name, value, description) VALUES ('sbindir','/usr/local/slash/sbin','Where are the sbin scripts kept');
INSERT INTO vars (name, value, description) VALUES ('send_mail','0','Turn On/Off the mailing list');
INSERT INTO vars (name, value, description) VALUES ('siteadmin','admin','The admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteadmin_name','Slash Admin','The pretty name for the admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteid','www.example.com','The unique ID for this site');
INSERT INTO vars (name, value, description) VALUES ('sitename','Slash Site','Name of the site');
INSERT INTO vars (name, value, description) VALUES ('siteowner','slash','What user this runs as');
INSERT INTO vars (name, value, description) VALUES ('slashdir','/usr/local/slash','Directory where Slash was installed');
INSERT INTO vars (name, value, description) VALUES ('slogan','Slash Site','Slogan of the site');
INSERT INTO vars (name, value, description) VALUES ('smtp_server','localhost','The mailserver for the site');
INSERT INTO vars (name, value, description) VALUES ('stats_reports','admin@example.com','Who to send daily stats reports to');
INSERT INTO vars (name, value, description) VALUES ('stir','3','Number of days before unused moderator points expire');
INSERT INTO vars (name, value, description) VALUES ('story_expire','600','Default expiration time for story cache');
INSERT INTO vars (name, value, description) VALUES ('submission_bonus','3','Bonus given to user if submission is used');
INSERT INTO vars (name, value, description) VALUES ('submission_speed_limit','300','How fast they can submit');
INSERT INTO vars (name, value, description) VALUES ('submiss_ts','1','print timestamp in submissions view');
INSERT INTO vars (name, value, description) VALUES ('submiss_view','1','allow users to view submissions queue');
INSERT INTO vars (name, value, description) VALUES ('submit_categories','Back','Extra submissions categories');
INSERT INTO vars (name, value, description) VALUES ('template_cache_size','0','Number of templates to store in cache (0 = unlimited)');
INSERT INTO vars (name, value, description) VALUES ('template_post_chomp','0','Chomp whitespace after directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('template_pre_chomp','0','Chomp whitespace before directives (0 = no, 1 = yes, 2 = collapse; 0 or 2 recommended)');
INSERT INTO vars (name, value, description) VALUES ('titlebar_width','100%','The width of the titlebar');
INSERT INTO vars (name, value, description) VALUES ('today','730512','(Obviated) Today converted to days past a long time ago');
INSERT INTO vars (name, value, description) VALUES ('tokenspercomment','6','Number of tokens to feed the system for each comment');
INSERT INTO vars (name, value, description) VALUES ('tokensperpoint','8','Number of tokens per point');
INSERT INTO vars (name, value, description) VALUES ('totalComments','0','Total number of comments posted');
INSERT INTO vars (name, value, description) VALUES ('totalhits','383','Total number of hits the site has had thus far');
INSERT INTO vars (name, value, description) VALUES ('updatemin','5','do slashd updates, default 5');
INSERT INTO vars (name, value, description) VALUES ('use_dept','1','use \"dept.\" field');
INSERT INTO vars (name, value, description) VALUES ('writestatus','0','Simple Boolean to determine if homepage needs rewriting');

