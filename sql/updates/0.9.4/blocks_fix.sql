ALTER table sectionblocks modify column bid varchar(30) NOT NULL DEFAULT '';
UPDATE sectionblocks set bid = 'index_more' where bid = 'more' and section = 'index';
UPDATE sectionblocks set bid = 'features_more' where bid = 'more' and section = 'features';
UPDATE sectionblocks set bid = 'articles_more' where bid = 'more' and section = 'articles';
UPDATE blocks set bid = 'index_more' where bid = 'more';
INSERT INTO blocks VALUES ('features_more','','CmdrTaco',1000,'static',NULL);
INSERT INTO blocks VALUES ('articles_more','','CmdrTaco',1000,'static',NULL);
UPDATE sectionblocks set bid = 'index_qlinks' where bid = 'quicklinks' and section = 'index';
UPDATE sectionblocks set bid = 'features_qlinks' where bid = 'quicklinks' and section = 'features';
UPDATE blocks set bid = 'index_qlinks' where bid = 'quicklinks';

INSERT INTO blocks VALUES ('features_qlinks','<!-- begin quicklinks block -->
<A HREF="http://server51.freshmeat.net/">Server 51</A><BR>
<A HREF="http://lists.slashdot.org/mailman/listinfo.cgi">Slash Mailing lists</A><BR>
<A HREF="http://www.slashcode.com/">Slashcode.com</A><BR>
<A HREF="http://slashdot.org/">Slashdot</A><BR>
<A HREF="http://andover.net/">Andover.Net</A><BR>
<A HREF="http://CmdrTaco.net/">CmdrTaco.net</A><BR>
<A HREF="http://www.cowboyneal.org/">Cowboyneal.org</A><BR>
<A HREF="http://pudge.net/">Pudge.Net</A><BR>
<A HREF="http://thinkgeek.com/">ThinkGeek</A><BR>
<!-- end quicklinks block -->',NULL,500,'static',NULL);

UPDATE blocks set block = '<!-- begin list filters section -->\r\n<FORM ENCTYPE=\"multipart/form-data\" action=\"$ENV{SCRIPT_NAME}\" method=\"POST\">\r\n<TABLE>\r\n        <TR>\r\n                <TD><INPUT TYPE=\"submit\" NAME=\"newfilter\" VALUE=\"Create a new filter\"></TD>\r\n        </TR>\r\n</TABLE>\r\n<TABLE BORDER=\"0\">\r\n        <TR>\r\n                <TD COLSPAN=\"9\">&nbsp;</TD>\r\n        </TR>\r\n        <TR>\r\n                <TD><B> Filter id <B></TD>\r\n                <TD><B> Regex <B></TD>\r\n                <TD><B> Modifier <B></TD>\r\n                <TD><B> Field <B></TD>\r\n                <TD><B> Ratio <B></TD>\r\n                <TD><B> Minimum match <B></TD>\r\n                <TD><B> Minimum length <B></TD>\r\n                <TD><B> Maximum length <B></TD>\r\n                <TD><B> Error message <B></TD>\r\n        </TR>\r\n' where bid = 'list_filters_header';

UPDATE blocks SET block = '\r\n</TABLE>\r\n<TABLE>\r\n        <TR>\r\n                <TD><INPUT TYPE=\"submit\" NAME=\"newfilter\" VALUE=\"Create a new filter\"></TD>\r\n        </TR>\r\n</TABLE>\r\n</FORM>\r\n<!-- end list filters -->\r\n' where bid = 'list_filters_footer';

UPDATE blocks SET block = '<TABLE BORDER=\"0\">\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\"><B>Filter id</B><BR>This is not editable<BR><BR></TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"hidden\" name=\"filter_id\" value=\"$filter_id\">&nbsp;&nbsp;</TD>\r\n                <TD VALIGN=\"top\"> $filter_id </TD><TD>&nbsp;</TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\"><B> Regex</B><BR>This is the base regex that you use for the filter.<BR><BR></TD>\r\n                <TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><FONT FACE=\"courier\" SIZE=\"+1\"><BR> $regex </FONT></TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" SIZE=\"30\" NAME=\"regex\" VALUE=\"$regex\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\"><B> Modifier </B><BR>The modifier for the regex /xxx/gi /xxx/g /xxx/<BR><BR></TD>\r\n                <TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><BR> $modifier </TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" SIZE=\"4\" NAME=\"modifier\" VALUE=\"$modifier\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\"><B> Field </B><BR>\r\n                This is the field you want to check. Refer to the code to make\r\n                sure you have the correct fieldname.\r\n                <BR><BR>\r\n                </TD><TD>&nbsp;&nbsp;</TD>\r\n                <TD VALIGN=\"top\"><BR> $field </TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" NAME=\"field\" VALUE=\"$field\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\">\r\n                <B> Ratio </B><BR>\r\n                The percentage of the fieldsize that you want the regex to match.\r\n                This is used to calculate the number of instances for the regex.\r\n                For instance, if the ration is .50, and the comment size is 100, \r\n                 then the regex ends up becoming /xxx{50,}/. Note: if this value is > 0,\r\n                 then you cannot use the minimum match field.\r\n                <BR><BR>\r\n                </TD>\r\n                <TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><BR> $ratio </TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" SIZE=\"8\" NAME=\"ratio\" VALUE=\"$ratio\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\"><B> Minimum match </B><BR> \r\n                This is the hardcoded minimum for the regex, if you\'re not using a ratio.\r\n                 For instance, if you set this to 10, your regex becomes /xxx/{10,}.\r\n                Note: You can\'t use ratio if you have this set to anything greater than 0\r\n                <BR><BR>\r\n                </TD>\r\n                <TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><BR> $minimum_match </TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" SIZE=\"8\" NAME=\"minimum_match\" VALUE=\"$minimum_match\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\"><B> Minimum length</B>\r\n                <BR>This is the minimum length of the comment in order for the filter to apply.\r\n                If set to zero, there will be no minimum size length.\r\n                <BR><BR>\r\n                </TD>\r\n                <TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><BR> $minimum_length </TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" SIZE=\"8\" NAME=\"minimum_length\" VALUE=\"$minimum_length\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD VALIGN=\"top\" WIDTH=\"40\"><B>Maximum length </B>\r\n                <BR>This is the maximum length a comment can be in order for the filter to apply.\r\n                If left to zero, there will be no maximum size length.\r\n                <BR><BR>\r\n                </TD>\r\n                <TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><BR> $maximum_length </TD>\r\n                <TD VALIGN=\"top\"><INPUT TYPE=\"text\" SIZE=\"10\" NAME=\"maximum_lenth\" VALUE=\"$maximum_length\"></TD>\r\n        </TR>\r\n        <TR>\r\n                <TD WIDTH=\"40\">\r\n                <B> Error message</B>\r\n                <BR>This is the error message that will be displayed if the filter is matched.<BR><BR>\r\n                </TD>\r\n<TD>&nbsp;&nbsp;</TD><TD VALIGN=\"top\"><BR> $err_message</TD>\r\n                <TD VALIGN=\"top\">$textarea</TD>\r\n        </TR>\r\n</TABLE>\r\n<TABLE BORDER=\"0\">\r\n        <TR>\r\n                \r\n                <TD><INPUT TYPE=\"submit\" NAME=\"updatefilter\" VALUE=\"Save filter\"></TD>      \r\n                <TD><INPUT TYPE=\"submit\" NAME=\"newfilter\" VALUE=\"Create a new filter\"></TD>\r\n                <TD><INPUT TYPE=\"submit\" NAME=\"deletefilter\" VALUE=\"Delete filter\"></TD>\r\n        </TR>\r\n</TABLE>\r\n' where bid = 'edit_filter';

INSERT INTO sectionblocks VALUES ('','admin_footer',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','admin_header',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','advertisement',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','colors',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','comment',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','commentswarning',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','edit_filter',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','emailsponsor',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','fancybox',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','footer',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','freespace2',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','header',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','index',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','index2',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_comment',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_fancybox',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_footer',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_header',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_index',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_story',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','light_titlebar',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','list_filters_footer',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','list_filters_header',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','lunch',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','mainmenu',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','menu',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','motd',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','organisation',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','newusermsg',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','pollitem',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','portalmap',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','postvote',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','radio',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','story',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','storymore',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','story_link',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','story_trailer',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','submit_after',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','submit_before',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','titlebar',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','topics',0,'',0,NULL,NULL,0);
INSERT INTO sectionblocks VALUES ('','uptime',0,'',0,NULL,NULL,0);
delete from sectionblocks where bid = 'testblock1';
INSERT INTO blocks VALUES ('AltaVista','','',500,'portald','');
INSERT INTO blocks VALUES ('amazon','','',500,'portald','');
INSERT INTO blocks VALUES ('apache','','',500,'portald','');
INSERT INTO blocks VALUES ('AskJeeves','','',500,'portald','');
INSERT INTO blocks VALUES ('askslashdot','','',500,'portald','');
INSERT INTO blocks VALUES ('bsd','','',500,'portald','');
INSERT INTO blocks VALUES ('CmdrTaco','','',500,'portald','');
INSERT INTO blocks VALUES ('dustpuppy','','',500,'portald','');
INSERT INTO blocks VALUES ('geeks','','',500,'portald','');
INSERT INTO blocks VALUES ('google','','',500,'portald','');
INSERT INTO blocks VALUES ('goto','','',500,'portald','');
INSERT INTO blocks VALUES ('Hemos','','',500,'portald','');
INSERT INTO blocks VALUES ('hollywoodbs','','',500,'portald','');
INSERT INTO blocks VALUES ('interview','','',500,'portald','');
INSERT INTO blocks VALUES ('JenniCam','','',500,'portald','');
INSERT INTO blocks VALUES ('macweek','','',500,'portald','');
INSERT INTO blocks VALUES ('natelinx','','',500,'portald','');
INSERT INTO blocks VALUES ('science','','',500,'portald','');
INSERT INTO blocks VALUES ('top10comments','','',500,'portald','');
INSERT INTO blocks VALUES ('Yahoo','','',500,'portald','');
INSERT INTO blocks VALUES ('yro','','',500,'portald','');
