#
# Table structure for table 'abusers'
#
# CREATE TABLE abusers (
 # abuser_id int(5) DEFAULT '0' NOT NULL auto_increment,
 # host_name varchar(25) DEFAULT '' NOT NULL,
 # pagename varchar(20) DEFAULT '' NOT NULL,
 # ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
 # PRIMARY KEY (abuser_id),
 # KEY host_name (host_name)
#);

update blocks set block = 'The user account "$name" on "$I{sitename}" has this address
associated with it.  A web user from $ENV{REMOTE_ADDR} has
just requested that ${name}\'s password be sent.  It is "$passwd".
You can change it after you login at:

    $I{rootdir}/users.pl

If you didn\'t ask for this, don\'t get your panties all in a knot.
You are seeing this message, not "them."  So if you can\'t be
trusted with your own password, we might have an issue, otherwise,
you can just disregard this message.

-- 
$I{siteadmin_name} <$I{adminmail}>
$I{sitename}
$I{slogan}
$I{rootdir}/' where bid = 'newusermsg';

delete from blocks where bid = 'worldnewyork';
delete from sectionblocks where bid = 'worldnewyork';

