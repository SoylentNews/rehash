#!/usr/bin/perl -w
use strict;
use DBIx::Password;

usage() unless $ARGV[0];
my $dbh = DBIx::Password->connect($ARGV[0]);

my $answer;
print "By running this I realize that there is no warranty and that
I am on my own. I have also read the poddoc for this script and
understand it. (yes/no)\n";
chomp($answer = <STDIN>);
exit unless $answer eq 'yes';



my $users_param = qq|
CREATE TABLE users_param (
	param_id int(11) NOT NULL auto_increment,
	uid int(11) DEFAULT '1' NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text,
	UNIQUE uid_key (uid,name),
	PRIMARY KEY (param_id)
)
|;

$dbh->do('ALTER TABLE stories add uid int(11)');
$dbh->do('ALTER TABLE newstories add uid int(11)');
$dbh->do('DROP TABLE newstories');
$dbh->do($users_param);
$dbh->do('DELETE FROM users WHERE UID < 1');
$dbh->do('DELETE FROM users_comments WHERE UID < 1');
$dbh->do('DELETE FROM users_index WHERE UID < 1');
$dbh->do('DELETE FROM users_info WHERE UID < 1');
$dbh->do('DELETE FROM users_key WHERE UID < 1');
$dbh->do('DELETE FROM users_prefs WHERE UID < 1');
$dbh->do("UPDATE users SET seclev=1 WHERE seclev=0");
my %story_authors;

my $authors = $dbh->selectall_arrayref("SELECT aid,seclev,lasttitle,section,deletedsubmissions from authors WHERE name != 'All Authors'");
for(@$authors) {
	my $uid;
	if($uid = $dbh->selectrow_array("SELECT BINARY uid from users WHERE nickname='$_->[0]'")) {
		print "Found $uid for $_->[0]\n";
		$story_authors{$_->[0]} = $uid; 
		$dbh->do("UPDATE users SET seclev='$_->[1]' WHERE uid=$uid");
		$dbh->do("INSERT INTO users_param (uid,name,value) VALUES ($uid, 'author', '1')");
		$dbh->do("INSERT INTO users_param (uid,name,value) VALUES ($uid, 'lasttitle', '$_->[2]')") if $_->[2];
		$dbh->do("INSERT INTO users_param (uid,name,value) VALUES ($uid, 'section', '$_->[3]')") if $_->[3];
		$dbh->do("INSERT INTO users_param (uid,name,value) VALUES ($uid, 'deletedsubmissions', '$_->[4]')") if $_->[4];
	}
}

my $users = $dbh->selectall_arrayref("SELECT uid,pubkey from users_key");
for(@$users) {
	my $string = $dbh->quote($_->[1]);
	$dbh->do("INSERT INTO users_param (uid,name,value) VALUES ($_->[0], 'pubkey', $string)");
}

for my $author (keys %story_authors) {
	print "Doing $author stories \n";
	my $sids = $dbh->selectcol_arrayref("SELECT sid FROM stories WHERE aid='$author'");
	for my $sid (@$sids) {
		$dbh->do("UPDATE stories SET uid=$story_authors{$author} WHERE sid='$sid'");	
	}
}

my $null_sids;
if($null_sids = $dbh->selectall_arrayref('select sid from stories WHERE uid is NULL')) {
	printf("Found stories lacking authors, select a uid to assign them to\n");
	for(keys %story_authors) {
		print "Authors $_ : $story_authors{$_}\n";
	}
	my $uid;
	chomp($uid = <STDIN>);
	$dbh->do("update stories SET uid=$uid WHERE uid is NULL");
}
$dbh->do('UPDATE users_prefs SET tzcode=UCASE(tzcode)');


print "What is your Anonymous Coward's uid?\n";
my $uid;
chomp($uid = <STDIN>);
$dbh->do("update submissions SET uid=$uid WHERE uid = -1");
$dbh->do("update comments SET uid=$uid WHERE uid = -1");


# This is what pudge will probably want to change :) 		-Brian
$dbh->do('ALTER TABLE users change passwd passwd varchar(32)');
$dbh->do('UPDATE users SET passwd=MD5(passwd)');
$dbh->do('CREATE TABLE newstories SELECT * from stories');

#cleanup time
$dbh->do('ALTER TABLE stories drop aid');
$dbh->do('ALTER TABLE newstories drop aid');
#Tables to just drop
my @tables = qw |
	authors         
	blocks          
	commentcodes    
	commentkey      
	commentmodes    
	content_filters
	dateformats     
	displaycodes    
	isolatemodes    
	issuemodes      
	maillist        
	postmodes
	sectionblocks   
	sessions        
	sortcodes       
	statuscodes     
	threshcodes     
	tzcodes         
	users_key
	vars
|;

for(@tables) {
	$dbh->do("DROP TABLE $_");
}

$dbh->disconnect;

sub usage {
	print "Usage:convert <DBIx:Password Virtual User>\n";
	print "\n\tIf no virtual user is given the coverter will not run\n\n";
	exit();
}

=head1 NAME

convertDBfrommain2bender.pl - Convert from 1.0.9 to 2.0 data

=head1 What does this do?

This converts the data from your Slash sites
to format you can then use to populate a new
Slash site.

=head1 What does this not do?

If you have customized your perl scripts this
will not help you. This does not save look and
feel from blocks. This basically handles stories
and users (which are the two large schema changes).

=head1 Ok, how should I use this.

This is what I would suggest:

First, make sure that your author accounts and
user accounts match. AKA for every aid you
have, you must have a username of the same.

Next, you need to make a decision, how are you going
to handle Anonymous Coward? If you installed slash
with the default data, you can just remove the first
6 accounts from your live data once you dump it
to disk and you are good to go. If this was not
the case you have a bit more work to do. You are
either going to have to move anonymous coward
once you set your site up before you insert your
original data (more on this in a couple of paragraphs)
or you are going to need to make sure that uid 1
is open for anonymous coward (and uid 2 if you
want to keep the account you will create during
the install). Remember that if you move your anonymous
user that you need to update the vars table with
the anonymous user's new uid.

I would also suggest that you remove all of the data
from stories, storiestuff, discussions and from
the poll tables just to make sure no collisions
happen.

Use mysqldump to make a copy of your data. Example:

mysqldump -u slash -p slash > datadump.sql

Now, use the database you are going to load your
slashsite in. This will save you the step of
setting up an additional virtual user.

Now, dump the data into the database. Example:

mysq -u -p slash < datadump.sql

Now, run the convert script with the proper
virtual user name.

Now, dump the data out. Example:

mysqldump -u slash -p slash --complete-insert --no-create-info > datadump

Now, install a slashsite and then dump this data into the site.

mysqldump -u slash -p slash < datadump

A couple of things, you may want to move some of your blocks over
by hand, and if you added or deleted any filters you will need
to move those by hand.


=head1 What am I likely to mess up?

Keep in mind that your install did create a user. You may
want to delete that user before dumping.

I would bet a fiver that someone does this on their live
database.

=head1 What is the warranty?

YMMV. There is none. Worked for me (I think).
Keep in mind that most people are accidents.

=cut
