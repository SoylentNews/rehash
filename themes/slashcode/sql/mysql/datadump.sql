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
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('colors','#FFFFFF,#222222,#111111,#DDDDDD,#999999,#DDDDDD,#FFFFFF,#DDDDDD,#660000,#BBBBBB',1000,'color','<P>This is a comma delimited list of colors that are split by comma and \r\nassigned to two arrays: $user->{fg} and $user->{bg}. <BR>The first half of these colors go into $user->{fg} and the last half go into $user->{bg}.</P>','index',0,'colors',0,'','',0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('features','<!-- begin features block -->\r\nThis is a place where you can put linkage to important stories\r\nthat you have on your site.\r\nYou can edit this space easily by just logging into backSlash, clicking\r\n\'Blocks\' from the admin menu, and editing the block named \'features\'.\r\n<!-- end features block -->\r\n\r\n',500,'static',NULL,'index',1,'features',1,'index.pl?section=features',NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('features_more','',1000,'static',NULL,'features',5,'more',0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('features_qlinks','<!-- begin quicklinks block -->\n<A HREF=\"http://newsforge.com/\">Newsforge</A><BR>\n<A HREF=\"http://lists.slashdot.org/mailman/listinfo.cgi\">Slash Mailing lists</A><BR>\n<A HREF=\"http://www.slashcode.com/\">Slashcode.com</A><BR>\n<A HREF=\"http://slashdot.org/\">Slashdot</A><BR>\n<A HREF=\"http://osdn.com/\">OSDN</A><BR>\n<A HREF=\"http://CmdrTaco.net/\">CmdrTaco.net</A><BR>\n<A HREF=\"http://www.cowboyneal.org/\">Cowboyneal.org</A><BR>\n<A HREF=\"http://pudge.net/\">Pudge.Net</A><BR>\n<A HREF=\"http://tangent.org/\">TangentOrg</A><BR>\n<A HREF=\"http://thinkgeek.com/\">ThinkGeek</A><BR>\n\n<!-- end quicklinks block -->',500,'static',NULL,'features',7,'Quick Links',0,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('index_more','',1000,'static',NULL,'index',5,'Older Stuff',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('index_qlinks','<!-- begin quicklinks block -->\r\n\r\nYou should put some links here to other sites that your users might enjoy.\r\n\r\n<!-- end quicklinks block -->\r\n\r\n',10000,'static',NULL,'index',7,'Quick Links',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('mysite','By editing the section called \"User Space\" on the user\r\npreferences page, you can cause this space to be filled\r\nwith some HTML code. Personal URLs?  Your Credit Card\r\nNumbers and Social Security numbers?  Well, maybe you\r\nbetter stick to URLs.\r\n',10000,'static',NULL,'index',-10,'User Space',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('poll','<FORM ACTION=\"//www.example.com/pollBooth.pl\">\r\n	<INPUT TYPE=\"hidden\" NAME=\"qid\" VALUE=\"1\"\r\n<B>Are you happy?</B>\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"1\">No\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"2\">Yes\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"3\">thorazine\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"4\">apathy\r\n<BR><INPUT TYPE=\"radio\" NAME=\"aid\" VALUE=\"5\">manic depressive\r\n<BR><INPUT TYPE=\"submit\" VALUE=\"Vote\"> [ <A HREF=\"//www.example.com/pollBooth.pl?qid=1&aid=-1\"><B>Results</B></A> | <A HREF=\"//www.example.com/pollBooth.pl?\"><B>Polls</B></A>  ] <BR>\r\nComments:<B>0</B> | Votes:<B>43</B>\r\n</FORM>\r\n',1000,'portald',NULL,'index',2,'Poll',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('top10comments','',500,'portald','','index',0,'10 Hot Comments',1,'',NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve, all_sections) VALUES ('userlogin','',1000,'static','','index',4,'Login',1,NULL,NULL,0,1);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('newestthree','<!-- newestthree -->',100,'static','','',0,'Newest Three',1,NULL,NULL,0);
INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('recenttopics','none yet',500,'static','Recent Topics','index',0,'Recent Topics',1,'',NULL,0);


#
# Dumping data for table 'code_param'
#


#
# Dumping data for table 'commentmodes'
#

#
# Dumping data for table 'comments'
#

INSERT INTO comments (sid, cid, pid, date, ipid, subnetid, subject, uid, points, lastmod, reason, signature) VALUES (1,1,0,'2000-01-25 15:47:36','8f2e0eec531acf0e836f6770d7990857','8f2e0eec531acf0e836f6770d7990857','First Post!',1,1,-1,0,'8f2e0eec531acf0e836f6770d7990857');

#
# Dumping data for table 'comment_text'
#

INSERT INTO comment_text (cid, comment) VALUES (1, 'This is the first post put into your newly installed Slash System.  There will be many more.  Many will be intelligent and well written.  Others will be drivel.  And then there will be a bunch of faceless anonymous morons who will attack you for no reason except that they are having a <a href="http://www.suck.com/daily/2000/03/22/4.html">bad day</a suck.com>.  But in the end it\'ll hopefully all be worth it, because those intelligent users will exchange useful ideas and hopefully learn something and grow as human beings.  Have fun!');

#
# Dumping data for table 'content_filters'
#

INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(?:\\s+)','comments','gi','postersubj',0.0000,7,0,'Lots of space in the subject ... lots of space in the head.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(?:\\s+)','comments','gi','postercomment',0.0000,40,0,'Lots of space in the comment ... lots of space in the head.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('(?:(?:\\W){5,})','comments','gi','postercomment',0.0000,5,25,'Junk character post.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('(?:\\b(?:[^a-zA-Z0-9])+\\b)','comments','gi','postercomment',0.0000,10,10,'Junk character post.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('(?:\\b(?:[^a-zA-Z0-9])+\\b)','comments','gi','postersubj',0.0000,10,10,'Junk character post.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(.)\\1{5,}$','comments','gi','postersubj',0.0000,0,0,'Junk character post.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(?:.)$','comments', 'gi','postersubj',0.0000,0,0,'One character. Hmmm. Gee, might this be a troll?');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(?:.)$','comments', 'gi','postercomment',0.0000,0,0,'One character. Hmmm. Gee, might this be a troll?');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('[\\\\\\,\\.\\-\\_\\*\\|\\}\\{\\]\\[\\@\\&\\%\\$\\s\\)\\(\\?\\!\\^\\=\\+\\~\\`\\\"\\\']','comments', 'gi','postercomment',0.6000,0,10,'Ascii art. How creative. Not here though.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('[^a-zA-Z0-9]','comments', 'gi','postercomment',0.6000,0,10,'Ascii Art. How creative. Not here though.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('[^a-zA-Z0-9]','comments', 'gi','postersubj',0.6000,0,10,'Ascii Art. How creative. Not here though.');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('[^a-z]','comments', 'g','postercomment',0.5000,0,2,'PLEASE DON\'T USE SO MANY CAPS. USING CAPS IS LIKE YELLING!');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('[^a-z]','comments', 'g','postersubj',0.9000,0,2,'PLEASE DON\'T USE SO MANY CAPS. USING CAPS IS LIKE YELLING!');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(?:)$','comments', 'gi','postersubj',0.0000,0,0,'Cat got your tongue? You mean you have nothing to say?');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('^(?:)$','comments', 'gi','postercomment',0.0000,0,0,'Cat got your tongue? You mean you have nothing to say?');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('\\w{80}','comments', '','postersubj',0.0000,0,0,'that\'s an awful long string of letters there!');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('\\w{80}','comments', '','postercomment',0.0000,0,0,'that\'s an awful long string of letters there!');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('feces','submissions', '','subj',0.0000,0,0,'too smelly to submit');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('feces','submissions', '','story',0.0000,0,0,'too smelly to submit');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('feces','submissions', '','email',0.0000,0,0,'too smelly to submit');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('goatse\\.cx','submissions', '','subj',0.0000,0,0,'definitely tired...');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('goatse\\.cx','submissions', '','story',0.0000,0,0,'definitely tired...');
INSERT INTO content_filters (regex, form, modifier, field, ratio, minimum_match, minimum_length, err_message) VALUES ('goatse\\.cx','submissions', '','email',0.0000,0,0,'definitely tired...');

#
# Dumping data for table 'dateformats'
#


#
# Dumping data for table 'discussions'
#

INSERT INTO discussions (id, sid, title, url, ts, topic, uid, commentcount, flags, section) VALUES (1, '00/01/25/1430236','You\'ve Installed Slash!','//www.example.com/article.pl?sid=00/01/25/1430236','2000-01-25 14:30:36',1,2,1,'dirty', 'articles');
INSERT INTO discussions (id, sid, title, url, ts, topic, uid, commentcount, flags, section) VALUES (2, '00/01/25/1236215','Now What?','//www.example.com/article.pl?sid=00/01/25/1236215','2000-01-25 17:36:15',1,2,0,'dirty', 'articles');
INSERT INTO discussions (id, sid, title, url, ts, topic, uid, commentcount, flags, section) VALUES (3, '','What flavor of ice cream?','//www.example.com/pollBooth.pl?section=&qid=1&aid=-1','2000-01-25 17:36:15',1,2,0,'dirty', 'articles');
INSERT INTO discussions (id, sid, title, url, ts, topic, uid, commentcount, flags, section) VALUES (4, '','Are you happy?','//www.example.com/pollBooth.pl?section=&qid=2&aid=-1','2000-01-25 17:36:15',1,2,0,'dirty', 'articles');

#
# Dumping data for table 'formkeys'
#


#
# Dumping data for table 'hitters'
#


#
# Dumping data for table 'menus'
#

INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','New User','[% constants.rootdir %]/users.pl?op=newuseradmin',10000,1);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Your Info','[% constants.rootdir %]/~[% user.nickname | fixparam %]/',1,10);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Log out','[% constants.rootdir %]/my/logout/',1,20);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','<b>Preferences:</b>','',1,30);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Homepage','[% constants.rootdir %]/my/homepage/',1,40);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Comments','[% constants.rootdir %]/my/comments/',1,50);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','You','[% constants.rootdir %]/my/',1,60);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','Password','[% constants.rootdir %]/my/password/',1,70);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('users','[% USE Slash %][% IF Slash.db.getMiscUserOpts.size %]Misc[% END %]', '[% constants.rootdir %]/my/misc/',1,75);
INSERT INTO menus (menu, label, value, seclev, menuorder) VALUES ('topics','Recent Topics','[% constants.rootdir %]/topics.pl?op=toptopics',0,80);

#
# Dumping data for table 'metamodlog'
#


#
# Dumping data for table 'moderatorlog'
#


#
# Dumping data for table 'pollanswers'
#

INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (1,1,'Chocolate',3);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (1,2,'Vanilla',1);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (1,3,'Strawberry',0);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (1,4,'Rocky Road',0);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (1,5,'Pepto bismol',1);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (2,1,'No',0);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (2,2,'Yes',2);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (2,3,'thorazine',3);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (2,4,'apathy',1);
INSERT INTO pollanswers (qid, aid, answer, votes) VALUES (2,5,'manic depressive',1);

#
# Dumping data for table 'pollquestions'
#

INSERT INTO pollquestions (qid, question, voters, date, discussion, uid, section) VALUES (1, 'What flavor of ice cream?', 5, '2000-01-16 19:11:10', 3, 2, 'index');
INSERT INTO pollquestions (qid, question, voters, date, discussion, uid, section) VALUES (2, 'Are you happy?', 7, '2000-01-19 16:23:00', 4, 2, 'features');

#
# Dumping data for table 'pollvoters'
#

#
# Dumping data for table 'related_links'
#

INSERT INTO related_links (keyword, name, link) VALUES ('slash','Slash','http://slashcode.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('slashcode','Slash','http://slashcode.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('intel','Intel','http://www.intel.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('linux','Linux','http://www.linux.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('redhat','Red Hat','http://www.redhat.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('red hat','Red Hat','http://www.redhat.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('www.example.com','www.example.com','http://www.example.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('slashdot','Slashdot','http://slashdot.org/');
INSERT INTO related_links (keyword, name, link) VALUES ('cmdrtaco','Rob Malda','http://CmdrTaco.net/');
INSERT INTO related_links (keyword, name, link) VALUES ('debian','Debian','http://www.debian.org/');
INSERT INTO related_links (keyword, name, link) VALUES ('zdnet','ZDNet','http://www.zdnet.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('news.com','News.com','http://www.news.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('cnn','CNN','http://www.cnn.com/');
INSERT INTO related_links (keyword, name, link) VALUES ('krow','Krow','http://tangent.org/~brian/');
INSERT INTO related_links (keyword, name, link) VALUES ('tangent','TangentOrg','http://tangent.org/');
INSERT INTO related_links (keyword, name, link) VALUES ('pudge','Pudge','http://pudge.net/');
INSERT INTO related_links (keyword, name, link) VALUES ('macperl','MacPerl','http://dev.macperl.org/');
INSERT INTO related_links (keyword, name, link) VALUES ('perl','Perl','http://use.perl.org/');

#
# Dumping data for table 'sections'
#

REPLACE INTO sections (section, artcount, title, issue, extras, type, qid) VALUES ('index',30,'Index',0,0,'collected', 1);
INSERT INTO sections (section, artcount, title, issue, extras) VALUES ('articles',30,'Articles',0,0);
INSERT INTO sections (section, artcount, title, issue, extras, qid) VALUES ('features',21,'Features',1,0,2);

#
# Dumping data for table 'section_topics'
#

INSERT INTO section_topics (section, tid, type) VALUES ('articles', 1, 1);
INSERT INTO section_topics (section, tid, type) VALUES ('articles', 2, 1);
INSERT INTO section_topics (section, tid, type) VALUES ('articles', 3, 1);
INSERT INTO section_topics (section, tid, type) VALUES ('articles', 4, 1);
INSERT INTO section_topics (section, tid, type) VALUES ('features', 1, 1);

#
# Dumping data for table 'sessions'
#


#
# Dumping data for table 'site_info'
#


#
# Dumping data for table 'stories'
#

INSERT INTO stories (sid, tid, uid, title, dept, time, hits, section, displaystatus, commentstatus, discussion, submitter, writestatus, qid) VALUES ('00/01/25/1430236',4,2,'You\'ve Installed Slash!','congratulations-dude','2000-08-28 20:47:46',0,'articles',0,0,1,2, 'dirty', 2);
INSERT INTO stories (sid, tid, uid, title, dept, time, hits, section, displaystatus, commentstatus, discussion, submitter, writestatus, qid) VALUES ('00/01/25/1236215',4,2,'Now What?','where-do-you-go-from-here','2000-01-25 08:32:02',0,'articles',0,0,2,2, 'dirty', NULL);


#
# Dumping data for table 'story_text'
#

INSERT INTO story_text (sid, introtext, bodytext, relatedtext) VALUES ('00/01/25/1236215','You should play around with the admin stuff.  Configure things to\r\nyour tastes.  You should also edit the variables (in the admin menu) to define things like your websites name and slogan.  You should also donate some money to the <A href=http://www.fsf.org>FSF</A> and <A href=http://slashdot.org>Read Slashdot</A>.\r\n','','<LI><A href=http://www.fsf.org>FSF</A></LI>\n<LI><A href=http://slashdot.org>Read Slashdot</A></LI>\n<LI><A HREF=\"//www.example.com/search.pl?topic=slash\">More on Slash</A></LI>\r\n<LI><A HREF=\"//www.example.com/search.pl?author=God\">Also by God</A></LI>');
INSERT INTO story_text (sid, introtext, bodytext, relatedtext) VALUES ('00/01/25/1430236','So it took some doing (hopefully not too much), and it looks like you\'ve got Slash installed and ready to rock.  You can now use <A href="/admin.pl">backSlash</A>, the Slash Code Administration tool, if you are logged in as the admin user you set up during installation.  And you might wanna start posting some stories too.','','<LI><A href=/admin.pl>backSlash</A></LI>\n<LI><A HREF=\"//www.example.com/search.pl?topic=slash\">More on Slash</A></LI>\r\n<LI><A HREF=\"//www.example.com/search.pl?author=God\">Also by God</A></LI>');

#
# Dumping data for table 'story_param'
#
INSERT INTO story_param (sid, name, value) VALUES ('00/01/25/1430236', 'qid', '2');


#
# dumping data from table 'story_topics'
#

INSERT INTO story_topics (sid,tid) VALUES ('00/01/25/1430236',4);
INSERT INTO story_topics (sid,tid) VALUES ('00/01/25/1236215',4);

#
# Dumping data for table 'submissions'
#

INSERT INTO submissions (subid, email, name, time, subj, story, tid, section, uid, del, ipid, subnetid) VALUES ('','somewhere@somewhere.com','PostMyStory','2000-01-25 15:25:08','This is the Submissions Area','This is where you read the submissions that your readers send you.  From here you can delete them (click the checkboxes and hit update) or attach little notes to them and flag them to be put on hold, or saved for quickies (all of these things are helpful when you have several people working on the backend at the same time).\r\n\r\n<P>Most of the time you\'ll just want to click on the title of the submission, and then either preview/post it, or delete it. ',4,'articles',2,0,'2','8f2e0eec531acf0e836f6770d7990857');

#
# Dumping data for table 'templates'
#


#
# Dumping data for table 'topics'
#

INSERT INTO topics (tid, name, image, alttext, width, height) VALUES (1,'news', 'topicnews.gif','News',34,44);
INSERT INTO topics (tid, name, image, alttext, width, height) VALUES (2,'linux', 'topiclinux.gif','Linux',60,70);
INSERT INTO topics (tid, name, image, alttext, width, height) VALUES (3,'slashdot', 'topicslashdot.gif','Slashdot',100,34);
INSERT INTO topics (tid, name, image, alttext, width, height) VALUES (4,'slash', 'topicslash.gif','Slash',81,36);

#
# Dumping data for table 'tzcodes'
#


#
# Dumping data for table 'users'
#

INSERT INTO users (uid, nickname, realemail, fakeemail, homepage, passwd, sig, seclev, matchname, newpasswd) VALUES (1,'Anonymous Coward','','','','','',0,'anonymouscoward',NULL);

#
# Dumping data for table 'users_comments'
#

INSERT INTO users_comments (uid, points, posttype, defaultpoints, highlightthresh, maxcommentsize, hardthresh, clbig, clsmall, reparent, nosigs, commentlimit, commentspill, commentsort, noscores, mode, threshold) VALUES (1,0,2,0,4,4096,0,0,0,1,0,50000,50,0,0,'thread',0);

#
# Dumping data for table 'users_hits'
#

INSERT INTO users_hits (uid, hits) VALUES (1,0);

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
