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
INSERT INTO code_param (type, code, name) VALUES ('section_topic_types',1,'default');
INSERT INTO code_param (type, code, name) VALUES ('extra_types', 1, 'text');
INSERT INTO code_param (type, code, name) VALUES ('extra_types', 2, 'list');

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
# Dumping data for table 'dst'
#

INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('America',     1, 2,  1, 0, 3, 2, -1, 0, 9);
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('Europe',      1, 1, -1, 0, 2, 1, -1, 0, 9);
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('Australia',   1, 2, -1, 0, 9, 2, -1, 0, 2);
INSERT INTO dst (region, selectable, start_hour, start_wnum, start_wday, start_month, end_hour, end_wnum, end_wday, end_month) VALUES ('New Zealand', 0, 2,  1, 0, 9, 2,  3, 0, 2);

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
# Dumping data for table 'modreasons'
#
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 0, 'Normal',        0, 0,  0, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 1, 'Offtopic',      1, 1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 2, 'Flamebait',     1, 1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 3, 'Troll',         1, 1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 4, 'Redundant',     1, 1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 5, 'Insightful',    1, 1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 6, 'Interesting',   1, 1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 7, 'Informative',   1, 1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 8, 'Funny',         1, 1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES ( 9, 'Overrated',     0, 0, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, fairfrac) VALUES (10, 'Underrated',    0, 0,  1, 0.5);


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
INSERT INTO sections (section, artcount, title, qid, issue, type) VALUES ('index',15,'Index','',0,'collected');


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
# Dumping data for table 'string_param'
#

INSERT INTO string_param (type, code, name) VALUES ('commentcodes','disabled','Comments Disabled');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes','enabled','Comments Enabled');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','friends_only','Just Friends');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','friends_fof_only','Just Friends and their Friends');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','no_foe','No Foes');
INSERT INTO string_param (type, code, name) VALUES ('commentcodes_extended','no_foe_eof','No Foes and No Friend\'s Foes');
INSERT INTO string_param (type, code, name) VALUES ('section_topic_type','topic_1','Default');
INSERT INTO string_param (type, code, name) VALUES ('yes_no','yes','yes');
INSERT INTO string_param (type, code, name) VALUES ('yes_no','no','no');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','','Unclassified');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','Hold','Hold');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','Quick','Quick');
INSERT INTO string_param (type, code, name) VALUES ('submission-notes','Back','Back');
INSERT INTO string_param (type, code, name) VALUES ('section_types','contained','Contained Section');
INSERT INTO string_param (type, code, name) VALUES ('section_types','collected','Collection of Sections');

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
INSERT INTO vars (name, value, description) VALUES ('absolutedir_secure','https://www.example.com','Absolute base URL of Secure HTTP site');
INSERT INTO vars (name, value, description) VALUES ('accesslog_insert_cachesize','0','Cache accesslog inserts and do this many all at once (0 to disable, if enabled, suggest value of 5 or so)');
INSERT INTO vars (name, value, description) VALUES ('ad_max', '6', 'Maximum ad number (must be at least ad_messaging_num)');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_num', '6', 'Which ad (env var AD_BANNER_x) is the "messaging ad"?');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_prob', '0.5', 'Probability that the messaging ad will be shown, if the circumstances are right');
INSERT INTO vars (name, value, description) VALUES ('ad_messaging_sections', '', 'Vertbar-separated list of sections where messaging ads can appear; if empty, all sections');
INSERT INTO vars (name, value, description) VALUES ('admin_check_clearpass', '0', 'Check whether admins have sent their Slash passwords in the clear?');
INSERT INTO vars (name, value, description) VALUES ('admin_clearpass_disable', '0', 'Should admins who send their Slash passwords in the clear have their admin privileges removed until they change their passwords?');
INSERT INTO vars (name, value, description) VALUES ('admin_formkeys', '0', 'Do admins have to bother with formkeys?');
INSERT INTO vars (name, value, description) VALUES ('admin_secure_ip_regex', '^127\\.', 'IP addresses or networks known to be secure.');
INSERT INTO vars (name, value, description) VALUES ('admin_timeout','30','time in minutes before idle admin session ends');
INSERT INTO vars (name, value, description) VALUES ('adminmail','admin@example.com','All admin mail goes here');
INSERT INTO vars (name, value, description) VALUES ('adminmail_mod','admin@example.com','All admin mail about moderation goes here');
INSERT INTO vars (name, value, description) VALUES ('adminmail_post','admin@example.com','All admin mail about comment posting goes here');
INSERT INTO vars (name, value, description) VALUES ('allow_anonymous','1','allow anonymous posters');
INSERT INTO vars (name, value, description) VALUES ('allow_moderation','1','allows use of the moderation system');
INSERT INTO vars (name, value, description) VALUES ('allow_nonadmin_ssl','0','0=users with seclev <= 1 cannot access the site over Secure HTTP; 1=they all can; 2=only if they are subscribers');
INSERT INTO vars (name, value, description) VALUES ('anonymous_coward_uid', '1', 'UID to use for anonymous coward');
INSERT INTO vars (name, value, description) VALUES ('anon_name_alt','An anonymous coward','Name of anonymous user to be displayed in stories');
INSERT INTO vars (name, value, description) VALUES ('apache_cache', '3600', 'Default times for the getCurrentCache().');
INSERT INTO vars (name, value, description) VALUES ('approved_url_schemes','ftp|http|gopher|mailto|news|nntp|telnet|wais|https','Schemes that can be used in comment links without being stripped of bogus chars');
INSERT INTO vars (name, value, description) VALUES ('approvedtags','B|I|P|A|LI|OL|UL|EM|BR|TT|STRONG|BLOCKQUOTE|DIV|ECODE','Tags that you can use');
INSERT INTO vars (name, value, description) VALUES ('approvedtags_break','P|LI|OL|UL|BR|BLOCKQUOTE|DIV','Tags that break words (see breakHtml())');
INSERT INTO vars (name, value, description) VALUES ('archive_delay','60','days to wait for story archiving');
INSERT INTO vars (name, value, description) VALUES ('archive_delay_mod','60','Days before moderator logs are expired');
INSERT INTO vars (name, value, description) VALUES ('archive_use_backup_db', '0', 'Should the archival process retrieve data from the backup database?');
INSERT INTO vars (name, value, description) VALUES ('articles_only','0','show only Articles in submission count in admin menu');
INSERT INTO vars (name, value, description) VALUES ('article_nocomment','0','Show no comments in article.pl');
INSERT INTO vars (name, value, description) VALUES ('authors_unlimited','100','Seclev for which authors have unlimited moderation');
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
INSERT INTO vars (name, value, description) VALUES ('charrefs_bad_entity','zwnj|zwj|lrm|rlm','Entities that approveCharref should always delete');
INSERT INTO vars (name, value, description) VALUES ('charrefs_bad_numeric','8204|8205|8206|8207|8236|8237|8238','Numeric references that approveCharref should always delete');
INSERT INTO vars (name, value, description) VALUES ('checklist_length','255','Length of user_index checklist fields (default is VARCHAR(255))');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_debug','1','Debug _comment_text cache activity to STDERR?');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_hours','96','Discussion age at which comments are no longer cached');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_max_keys','3000','Maximum number of keys in the _comment_text cache');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_newstyle','0','Use _getCommentTextNew?');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_max_frac','0.75','In purging the _comment_text cache, fraction of max_keys to target');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_min_comm','50','Min number comments in a discussion for it to force a cache purge');
INSERT INTO vars (name, value, description) VALUES ('comment_cache_purge_min_req','5','Min number times a discussion must be requested to force a cache purge');
INSERT INTO vars (name, value, description) VALUES ('comment_compress_slice','500','Chars to slice comment into for compressOk');
INSERT INTO vars (name, value, description) VALUES ('comment_homepage_disp','50','Chars of poster URL to show in comment header');
INSERT INTO vars (name, value, description) VALUES ('comment_maxscore','5','Maximum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_minscore','-1','Minimum score for a specific comment');
INSERT INTO vars (name, value, description) VALUES ('comment_nonstartwordchars','.,;:/','Chars which cannot start a word (will be forcibly separated from the rest of the word by a space) - this works around a Windows/MSIE "widening" bug - set blank for no action');
INSERT INTO vars (name, value, description) VALUES ('comment_startword_workaround','1','Should breakHtml() insert kludgy HTML to work around an MSIE bug?');
INSERT INTO vars (name, value, description) VALUES ('comments_codemode_wsfactor','0.5','Whitespace factor for CODE posting mode');
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
INSERT INTO vars (name, value, description) VALUES ('comments_response_limit','5','interval between reply and submit');
INSERT INTO vars (name, value, description) VALUES ('comments_speed_limit','120','seconds delay before repeat posting');
INSERT INTO vars (name, value, description) VALUES ('comments_wsfactor','1.0','Whitespace factor');
INSERT INTO vars (name, value, description) VALUES ('commentstatus','0','default comment code');
INSERT INTO vars (name, value, description) VALUES ('content_type_webpage','text/html','The Content-Type field for webpages');
INSERT INTO vars (name, value, description) VALUES ('cookiedomain','','Domain for cookie to be active (normally leave blank)');
INSERT INTO vars (name, value, description) VALUES ('cookiepath','/','Path on server for cookie to be active');
INSERT INTO vars (name, value, description) VALUES ('cookiesecure','1','Set the secure flag in cookies if SSL is on?');
INSERT INTO vars (name, value, description) VALUES ('currentqid',1,'The Current Question on the homepage pollbooth');
INSERT INTO vars (name, value, description) VALUES ('daily_attime','00:00:00','Time of day to run dailyStuff (in TZ daily_tz; 00:00:00-23:59:59)');
INSERT INTO vars (name, value, description) VALUES ('daily_last','2000-01-01 01:01:01','Last time dailyStuff was run (GMT)');
INSERT INTO vars (name, value, description) VALUES ('delayed_inserts_off','1','This turns off delayed inserts (which you probably want to do)');
INSERT INTO vars (name, value, description) VALUES ('daily_tz','EST','Base timezone for running dailyStuff');
INSERT INTO vars (name, value, description) VALUES ('datadir','/usr/local/slash/www.example.com','What is the root of the install for Slash');
INSERT INTO vars (name, value, description) VALUES ('default_rss_template','default','name of default rss template used by portald');
INSERT INTO vars (name, value, description) VALUES ('defaultcommentstatus','0','default code for article comments- normally 0=posting allowed');
INSERT INTO vars (name, value, description) VALUES ('defaultdisplaystatus','0','Default display status ...');
INSERT INTO vars (name, value, description) VALUES ('defaultsection','articles','Default section to display');
INSERT INTO vars (name, value, description) VALUES ('defaulttopic','1','Default topic to use');
INSERT INTO vars (name, value, description) VALUES ('delete_old_stories', '0', 'Delete stories and discussions that are older than the archive delay.');
INSERT INTO vars (name, value, description) VALUES ('discussion_approval', '0', 'If this is set to 1, set all user created discussions when created to 0 so that they must be approved');
INSERT INTO vars (name, value, description) VALUES ('discussion_create_seclev','1','Seclev required to create discussions (yes, this could be an ACL in the future).');
INSERT INTO vars (name, value, description) VALUES ('discussion_default_topic', '1', 'Default topic of user-created discussions.');
INSERT INTO vars (name, value, description) VALUES ('discussion_display_limit', '30', 'Number of default discussions to list.');
INSERT INTO vars (name, value, description) VALUES ('discussionrecycle','0','Default is that recycle never occurs on recycled discussions. This number is valued in days.');
INSERT INTO vars (name, value, description) VALUES ('discussions_speed_limit','300','seconds delay before repeat discussion');
INSERT INTO vars (name, value, description) VALUES ('do_expiry','1','Flag which controls whether we expire users.');
INSERT INTO vars (name, value, description) VALUES ('down_moderations','-6','number of how many comments you can post that get down moderated');
INSERT INTO vars (name, value, description) VALUES ('draconian_charrefs','0','Enable strictest-possible rules for disallowing HTML entities/character references?');
INSERT INTO vars (name, value, description) VALUES ('enable_index_topic','','set this to the value in string param for index topic \(something like "topic_4"\)');
INSERT INTO vars (name, value, description) VALUES ('fancyboxwidth','200','What size should the boxes be in?');
INSERT INTO vars (name, value, description) VALUES ('feature_story_enabled','0','Simple Boolean to determine if homepage prints feature story');
INSERT INTO vars (name, value, description) VALUES ('formkey_timeframe','14400','The time frame that we check for a formkey');
INSERT INTO vars (name, value, description) VALUES ('freshenup_max_stories','100','Maximum number of article.shtml files to write at a time in freshenup.pl');
INSERT INTO vars (name, value, description) VALUES ('get_titles','0','get the story titles');
INSERT INTO vars (name, value, description) VALUES ('goodkarma','25','Users get bonus points for posts if karma above this value');
INSERT INTO vars (name, value, description) VALUES ('http_proxy','','http://proxy.www.example.com');
INSERT INTO vars (name, value, description) VALUES ('id_md5_vislength','5','Num chars to display for ipid/subnetid (0 for all)');
INSERT INTO vars (name, value, description) VALUES ('imagedir','//www.example.com/images','Absolute URL for image directory');
INSERT INTO vars (name, value, description) VALUES ('index_gse_backup_prob','0','Probability that index.pl getStoriesEssentials will look to backup_db_user instead of the main db: 0=never, 1=always');
INSERT INTO vars (name, value, description) VALUES ('index_handler','index.pl','The perl servlet to call fo conections to the root of the server.');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_ip','4','Downmods at which an IP is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_subnet','6','Downmods at which a subnet is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_downmods_user','4','Downmods at which a user is considered a troll');
INSERT INTO vars (name, value, description) VALUES ('istroll_ipid_hours','72','Hours back that getIsTroll checks IPs for comment mods');
INSERT INTO vars (name, value, description) VALUES ('istroll_uid_hours','72','Hours back that getIsTroll checks uids for comment mods');
INSERT INTO vars (name, value, description) VALUES ('karma_adj','-10=Terrible|-1=Bad|0=Neutral|12=Positive|25=Good|99999=Excellent','Adjectives that describe karma, used if karma_obfuscate is set (best to keep aligned with badkarma, m2_maxbonus_karma, and goodkarma)');
INSERT INTO vars (name, value, description) VALUES ('karma_obfuscate','0','Should users see, not their numeric karma score, but instead an adjective describing their approximate karma?');
INSERT INTO vars (name, value, description) VALUES ('label_ui','0','Whether to label some things in the admin ui');
INSERT INTO vars (name, value, description) VALUES ('lastlookmemory','3600','Amount of time the uid last looked-at will be remembered/displayed');
INSERT INTO vars (name, value, description) VALUES ('lastComments','0','Last time we checked comments for moderation points');
INSERT INTO vars (name, value, description) VALUES ('lastsrandsec','awards','Last Block used in the semi-random block');
INSERT INTO vars (name, value, description) VALUES ('lenient_formkeys','0','0 - only ipid, 1 - ipid OR subnetid, in formkey validation check');
INSERT INTO vars (name, value, description) VALUES ('log_admin','1','This turns on/off entries to the accesslog. If you are a small site and want a true number for your stats turn this off.');
INSERT INTO vars (name, value, description) VALUES ('log_db_user','','The virtual user of the database that the code should write accesslog to. If you don\'t know what this is for, you should leave it blank.');
INSERT INTO vars (name, value, description) VALUES ('logdir','/usr/local/slash/www.example.com/logs','Where should the logs be found?');
INSERT INTO vars (name, value, description) VALUES ('lonetags','P|LI|BR|IMG','Tags that don\'t need to be closed');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_hitcount','3','Number of hits on comments.pl before user can be considered eligible for moderation');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_percentage','0.8','Percentage of users eligible to moderate');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_end', '0.8888', 'Ending percentage into the pool of eligible moderators (used by moderatord)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_fairratio', '1.3', 'Factor of fairness ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_fairtotal', '1.3', 'Factor of fairness total in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_stirratio', '1.3', 'Factor of stirred-points ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_start', '0.167', 'Starting percentage into the pool of eligible moderators (used by moderatord)');
INSERT INTO vars (name, value, description) VALUES ('m2_batchsize', '300', 'Maximum number of moderations processed for M2 reconciliation per execution of moderation daemon.');
INSERT INTO vars (name, value, description) VALUES ('m2_comments','10','Number of comments for meta-moderation - if more than about 15, doublecheck that users_info.mods_saved is large enough');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus', '9', 'Number of M2 votes per M1 before it is reconciled by consensus - if not odd, will be forced to next highest odd number');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus_waitpow', '1', 'Positive real number, 0.2 to 5 is sensible. Between 0 and 1, older mods are chosen for M2 preferentially. Greater than 1, newer');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences','0.00=0,+2,-100,-1|0.15=-2,+1,-40,-1|0.30=-0.5,+0.5,-20,0|0.35=0,0,-10,0|0.49=0,0,-4,0|0.60=0,0,+1,0|0.70=0,0,+2,0|0.80=+0.01,-1,+3,0|0.90=+0.02,-2,+4,0|1.00=+0.05,0,+5,+0.5','Rewards and penalties for M2ers and moderator, up to the given amount of fairness (0.0-1.0): numbers are 1, tokens to fair-voters, 2, tokens to unfair-voters, 3, tokens to moderator, and 4, karma to moderator');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_token_max','25','Maximum number of tokens a user can have, for being on the consensus side of an M2 or being judged Fair, to merit gaining tokens');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_token_min','-999999','Minimum number of tokens a user must have, for being on the consensus side of an M2 to merit gaining tokens');
INSERT INTO vars (name, value, description) VALUES ('m2_freq','86400','In seconds, the maximum frequency which users can metamoderate');
INSERT INTO vars (name, value, description) VALUES ('m2_maxbonus_karma','12','Usually about half of goodkarma');
INSERT INTO vars (name, value, description) VALUES ('m2_min_daysbackcushion','2','The minimum days-back cushion');
INSERT INTO vars (name, value, description) VALUES ('m2_mintokens','0','The min M2 tokens');
INSERT INTO vars (name, value, description) VALUES ('m2_range_offset','0.9','Offset for M2 assignment ranges');
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
INSERT INTO vars (name, value, description) VALUES ('mod_elig_hoursback','48','Hours back in accesslog to look for mod elig');
INSERT INTO vars (name, value, description) VALUES ('mod_elig_minkarma','0','The min M1 karma');
INSERT INTO vars (name, value, description) VALUES ('mod_karma_bonus_max_downmods',2,'How many times can you downmod a comment without it losing its karma bonus? (bonus lost at value+1th downmod) (set very high to disable)');
INSERT INTO vars (name, value, description) VALUES ('mod_same_subnet_forbid','1','Forbid users from moderating any comments posted by someone in their subnet?');
INSERT INTO vars (name, value, description) VALUES ('mod_stats_reports','admin@example.com','Who to send daily moderation stats reports to');
INSERT INTO vars (name, value, description) VALUES ('mod_stir_recycle_fraction', '1.0', 'What fraction of unused mod points get recycled back into the system?');
INSERT INTO vars (name, value, description) VALUES ('mod_stir_token_cost','2','What is the token cost of having each mod point stirred?');
INSERT INTO vars (name, value, description) VALUES ('mod_token_decay_days','14','How many days of inactivity before tokens start to decay?');
INSERT INTO vars (name, value, description) VALUES ('mod_token_decay_perday','1','If inactivity, how many tokens lost per day?');
INSERT INTO vars (name, value, description) VALUES ('mod_unm2able_token_cost','1','What is the token cost of performing an un-M2able mod?');
INSERT INTO vars (name, value, description) VALUES ('mod_up_points_needed','','Need more than 1 point to mod up? Hash');
INSERT INTO vars (name, value, description) VALUES ('moderatord_catchup_count','2','The number of times moderatord will loop if replication is used and is too far behind our threshold.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_catchup_sleep','2','The number of seconds moderatord will wait each time it loops if replication is behind.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_debug_info', '1', 'Add in more detailed information into slashd.log for moderation task info. This WILL increase the size by slashd.log quite a bit, so use only if you need to.');
INSERT INTO vars (name, value, description) VALUES ('moderatord_lag_threshold','100000','The number of updates replication must be within before moderatord will run using the replicated handle. If this threshold isn\'t met, moderatord will not run.');
INSERT INTO vars (name, value, description) VALUES ('modviewseclev','100','Minimum seclev to see moderation totals on a comment');
INSERT INTO vars (name, value, description) VALUES ('multitopics_enabled','0','whether or not to allow stories to have multiple topics');
INSERT INTO vars (name, value, description) VALUES ('nesting_maxdepth','3','Maximum depth to which <BLOCKQUOTE>-type tags can be nested');
INSERT INTO vars (name, value, description) VALUES ('newsletter_body','0','Print bodytext, not merely introtext, in newsletter.');
INSERT INTO vars (name, value, description) VALUES ('noflush_accesslog','0','DO NOT flush the accesslog table, 0=Flush, 1=No Flush');
INSERT INTO vars (name, value, description) VALUES ('offer_insecure_login_link','0','Offer the user the \'totally insecure but very convenient\' index.pl login link');
INSERT INTO vars (name, value, description) VALUES ('organise_stories','','organise story blocks');
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
INSERT INTO vars (name, value, description) VALUES ('recent_topic_img_count','5','Number of recent topics to store in the template "recentTopics"');
INSERT INTO vars (name, value, description) VALUES ('recent_topic_txt_count','5','Number of recent topics to store in the block "recenttopics"');
INSERT INTO vars (name, value, description) VALUES ('rootdir','//www.example.com','Base URL of site; used for creating on-site links that need protocol-inspecific URL (so site can be used via HTTP and HTTPS at the same time)');
INSERT INTO vars (name, value, description) VALUES ('rss_expire_days','7','Number of days till we blank the data from the database (the signatures still stick around though)');
INSERT INTO vars (name, value, description) VALUES ('rss_store','0','Should we be saving incomming submissions for rss');
INSERT INTO vars (name, value, description) VALUES ('run_ads','0','Should we be running ads?');
INSERT INTO vars (name, value, description) VALUES ('runtask_verbosity','3','How much information runtask should write to slashd.log: 0-3 or empty string to use slashd_verbosity');
INSERT INTO vars (name, value, description) VALUES ('sbindir','/usr/local/slash/sbin','Where are the sbin scripts kept');
INSERT INTO vars (name, value, description) VALUES ('search_google','0','Turn on to disable local search (and invite users to use google.com)');
INSERT INTO vars (name, value, description) VALUES ('section','index','This is the current setting for section.');
INSERT INTO vars (name, value, description) VALUES ('send_mail','1','Turn On/Off to allow the system to send email messages.');
INSERT INTO vars (name, value, description) VALUES ('siteadmin','admin','The admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteadmin_name','Slash Admin','The pretty name for the admin for the site');
INSERT INTO vars (name, value, description) VALUES ('siteid','www.example.com','The unique ID for this site');
INSERT INTO vars (name, value, description) VALUES ('sitename','Slash Site','Name of the site');
INSERT INTO vars (name, value, description) VALUES ('siteowner','slash','What user this runs as');
INSERT INTO vars (name, value, description) VALUES ('sitepublisher','Me','The entity that publishes the site');
INSERT INTO vars (name, value, description) VALUES ('slashbox_sections','0','Allow used-selected slashboxes in sections');
INSERT INTO vars (name, value, description) VALUES ('slashd_verbosity','2','How much information slashd (and runtask) should write to slashd.log: 0-3, 3 can be a lot');
INSERT INTO vars (name, value, description) VALUES ('slashdir','/usr/local/slash','Directory where Slash was installed');
INSERT INTO vars (name, value, description) VALUES ('slogan','Slash Site','Slogan of the site');
INSERT INTO vars (name, value, description) VALUES ('smtp_server','localhost','The mailserver for the site');
INSERT INTO vars (name, value, description) VALUES ('stats_reports','admin@example.com','Who to send daily stats reports to');
INSERT INTO vars (name, value, description) VALUES ('stats_sfnet_groupids','4421','List of sf.net group IDs to keep stats on');
INSERT INTO vars (name, value, description) VALUES ('stir','3','Number of days before unused moderator points expire');
INSERT INTO vars (name, value, description) VALUES ('story_expire','600','Default expiration time for story cache');
INSERT INTO vars (name, value, description) VALUES ('submiss_ts','1','print timestamp in submissions view');
INSERT INTO vars (name, value, description) VALUES ('submiss_view','1','allow users to view submissions queue');
INSERT INTO vars (name, value, description) VALUES ('submission_bonus','3','Bonus given to user if submission is used');
INSERT INTO vars (name, value, description) VALUES ('submissions_speed_limit','300','How fast they can submit');
INSERT INTO vars (name, value, description) VALUES ('submit_categories','Back','Extra submissions categories');
INSERT INTO vars (name, value, description) VALUES ('submit_extra_sort_key', '', 'Provides an additional submission list sorted on the given field name');
INSERT INTO vars (name, value, description) VALUES ('submit_forgetip_hours','720','Hours after which a submissions\'s ipid/subnetid are forgotten; set very large to disable');
INSERT INTO vars (name, value, description) VALUES ('submit_forgetip_maxrows','100000','Max number of rows to forget IPs of at once');
INSERT INTO vars (name, value, description) VALUES ('submit_forgetip_minsubid','0','Minimum subid to start forgetting IP at');
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
INSERT INTO vars (name, value, description) VALUES ('tokenspercomment','6','Number of tokens to feed the system for each comment');
INSERT INTO vars (name, value, description) VALUES ('tokensperpoint','8','Number of tokens per point');
INSERT INTO vars (name, value, description) VALUES ('top10comm_num','10','Number of comments wanted for the Top 10 Comments slashbox (if not 10, you ought to rename it maybe)');
INSERT INTO vars (name, value, description) VALUES ('totalComments','0','Total number of comments posted');
INSERT INTO vars (name, value, description) VALUES ('totalhits','383','Total number of hits the site has had thus far');
INSERT INTO vars (name, value, description) VALUES ('updatemin','5','do slashd updates, default 5');
INSERT INTO vars (name, value, description) VALUES ('use_dept','1','use \"dept.\" field');
INSERT INTO vars (name, value, description) VALUES ('user_comment_display_default','24','Number of comments to display on user\'s info page');
INSERT INTO vars (name, value, description) VALUES ('user_submitter_display_default','24','Number of stories to display on user\'s info page');
INSERT INTO vars (name, value, description) VALUES ('users_bio_length','1024','Length allowed for user bio');
INSERT INTO vars (name, value, description) VALUES ('users_show_info_seclev','0','Minimum seclev to view a user\s info');
INSERT INTO vars (name, value, description) VALUES ('users_speed_limit','20','How fast a user can change their prefs');
INSERT INTO vars (name, value, description) VALUES ('writestatus','ok','Simple Boolean to determine if homepage needs rewriting');
