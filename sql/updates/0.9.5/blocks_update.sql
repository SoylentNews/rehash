insert into blocks values ('light_story_link',
'qq|
<!-- begin light_story_link block -->

<P><B>( </B>

<!-- end story_link block -->

|',
NULL,500,'eval',
'<P>
The eval code that creates the block that has the link to the article.pl
with the sid of the particular story.
</P>',
'qq|

<!-- begin light_story_link block -->

<P><B>( </B>

<!-- end story_link block -->

|'
);
insert into sectionblocks values ('','light_story_link',0,'',0,NULL,'',0);
insert into blocks values ('light_story_trailer',
'qq|

<!-- begin story_trailer block -->

                                <B>)</B></P>

<!-- end story_trailer block -->

|',
NULL,500,'eval',
'<P>
The code that\'s evaled to create the closing part of the story block.
</P>',
'qq|

<!-- begin story_trailer block -->

                                <B>)</B></P>

<!-- end story_trailer block -->

|');
insert into sectionblocks values ('','light_story_trailer',0,'',0,NULL,'',0);

update blocks set type = 'eval' where bid = 'story_link';

update sectionblocks set ordernum = -1, portal = 1 where bid = 'uptime';  

update blocks set block = 'The user account \'$name\' on  has this email
associated with it.  A web user from $ENV{REMOTE_ADDR} has
just requested that $name\'s password be sent.  It is \'$passwd\'.
You can change it after you login at /users.pl

If you didn\'t ask for this, don\'t get your panties all in a knot.
You are seeing this message, not "them".  So if you can\'t be
trusted with your own password, we might have an issue, otherwise,
you can just disregard this message.


--$I{adminmail}', 
blockbak = 'The user account \'$name\' on  has this email
associated with it.  A web user from $ENV{REMOTE_ADDR} has
just requested that $name\'s password be sent.  It is \'$passwd\'.
You can change it after you login at /users.pl

If you didn\'t ask for this, don\'t get your panties all in a knot.
You are seeing this message, not "them".  So if you can\'t be
trusted with your own password, we might have an issue, otherwise,
you can just disregard this message.


--$I{adminmail}'
 where bid = 'newusermsg';

