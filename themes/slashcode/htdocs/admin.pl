#!/usr/bin/perl -w

###############################################################################
# admin.pl - this code runs the site's administrative tasks page 
#
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#  $Id$
###############################################################################
use strict;
use lib '../';
use vars '%I';
use Image::Size;
use Slash;
use HTML::Entities;

sub main {
	*I = getSlashConf();
	getSlash();
	getSection('admin');

	my($tbtitle); 
	if ($I{F}{op} =~ /^preview|edit$/ && $I{F}{title}) {
		# Show submission title on browser's titlebar.
		$tbtitle = $I{F}{title};
		$tbtitle =~ s/"/'/g;
		$tbtitle = " - \"$tbtitle\"";
		# Undef the form title value if we have SID defined since the editor
		# will have to get it from the database anyways.
		undef $I{F}{title} if $I{F}{sid} && $I{F}{op} eq 'edit';
	}

	header("backSlash $I{U}{tzcode} $I{U}{offset}$tbtitle", 'admin');

	# Admin Menu
	print "<P>&nbsp;</P>" unless $I{U}{aseclev};

	my $op = $I{F}{op};
	if (!$I{U}{aseclev}) {
		titlebar('100%', 'back<I>Slash</I> Login');
		adminLoginForm();

	} elsif ($op eq 'logout') {
		$I{dbh}->do('DELETE FROM sessions WHERE aid=' . $I{dbh}->quote($I{U}{aid}));
		titlebar('100%', 'back<I>Slash</I> Buh Bye');
		adminLoginForm();

	} elsif ($I{F}{topicdelete}) {
		topicDelete();
		topicEd();

	} elsif ($I{F}{topicsave}) {
		topicSave();
		topicEd();

	} elsif ($I{F}{topiced} || $op eq 'topiced' || $I{F}{topicnew}) {
		topicEd();

	} elsif ($op eq 'save') {
		saveStory();

	} elsif ($op eq 'update') {
		updateStory();

	} elsif ($op eq 'list') {
		titlebar('100%', 'Story List', 'c');
		listStories();

	} elsif ($op eq 'delete') {
		rmStory($I{F}{sid});
		listStories();

	} elsif ($op eq 'preview') {
		editstory('');

	} elsif ($op eq 'edit') {
		editstory($I{F}{sid});

	} elsif ($op eq 'topics') {
		listtopics($I{U}{aseclev});

	} elsif ($op eq 'colored' || $I{F}{colored} || $I{F}{colorrevert} || $I{F}{colorpreview}) {
		colorEdit($I{U}{aseclev});

	} elsif ($I{F}{colorsave} || $I{F}{colorsavedef} || $I{F}{colororig}) {
		colorSave();
		colorEdit($I{U}{aseclev});

	} elsif($I{F}{blockdelete_cancel} || $op eq "blocked") {
		blockEdit($I{U}{aseclev},$I{F}{bid});

	} elsif($I{F}{blocknew}) {
		blockEdit($I{U}{aseclev});

	} elsif($I{F}{blocked1}) {
		blockEdit($I{U}{aseclev}, $I{F}{bid1});

	} elsif($I{F}{blocked2}) {
		blockEdit($I{U}{aseclev}, $I{F}{bid2});

	} elsif($I{F}{blocksave} || $I{F}{blocksavedef}) {
		blockSave($I{F}{thisbid});
		blockEdit($I{U}{aseclev}, $I{F}{thisbid});

	} elsif($I{F}{blockrevert}) {
		blockRevert($I{F}{thisbid});
		blockEdit($I{U}{aseclev}, $I{F}{thisbid});

	} elsif($I{F}{blockdelete}) {
		blockEdit($I{U}{aseclev},$I{F}{thisbid});

	} elsif($I{F}{blockdelete1}) {
		blockEdit($I{U}{aseclev},$I{F}{bid1});

	} elsif($I{F}{blockdelete2}) {
		blockEdit($I{U}{aseclev},$I{F}{bid2});

	} elsif($I{F}{blockdelete_confirm}) {
		blockDelete($I{F}{deletebid});
		blockEdit($I{U}{aseclev});

	} elsif ($op eq 'authors') {
		authorEdit($I{F}{thisaid});

	} elsif ($I{F}{authoredit}) {
		authorEdit($I{F}{myaid});

	} elsif ($I{F}{authornew}) {
		authorEdit();

	} elsif ($I{F}{authordelete}) {
		authorDelete($I{F}{myaid});

	} elsif ($I{F}{authordelete_confirm} || $I{F}{authordelete_cancel}) {
		authorDelete($I{F}{thisaid});
		authorEdit();

	} elsif ($I{F}{authorsave}) {
		authorSave();
		authorEdit($I{F}{myaid});

	} elsif ($op eq 'vars') {
		varEdit($I{F}{name});	

	} elsif ($op eq 'varsave') {
		varSave();
		varEdit($I{F}{name});

	} elsif ($op eq "listfilters") {
		titlebar("100%","List of comment filters","c");
		listFilters();

	} elsif ($I{F}{editfilter}) {
		titlebar("100%","Edit Comment Filter","c");
		editFilter($I{F}{filter_id});

	} elsif ($I{F}{updatefilter}) {
		updateFilter("update");

	} elsif ($I{F}{newfilter}) {
		updateFilter("new");

	} elsif ($I{F}{deletefilter}) {
		updateFilter("delete");

	} else {
		titlebar('100%', 'Story List', 'c');
		listStories();
	}

	writelog('admin', $I{U}{aid}, $op, $I{F}{sid});

	# Display who is logged in right now.
	footer();

	# zero the refresh flag 
	# and undef sid sequence array
	if ($I{story_refresh}) {
		$I{story_refresh} = 0;
		# garbage collection 
		undef $I{sid_array};
	}
	# zero the order count
	$I{StoryCount} = 0;
}

##################################################################
# Misc
sub adminLoginForm {	
	print "\n<!-- begin admin login form -->\n<CENTER>",
		$I{query}->startform(-method => 'POST', -action => $ENV{SCRIPT_NAME}),
		$I{query}->hidden(-name => 'op', -default => 'adminlogin', -override => 1),
		'<TABLE><TR><TD ALIGN="RIGHT">Login</TD>
		<TD>', $I{query}->textfield(-name => 'aaid'), "</TD></TR>",
		'<TR><TD ALIGN="RIGHT">Password</TD>
		<TD>', $I{query}->password_field(-name => 'apasswd'),"</TD></TR>",
		'<TD> </TD><TD><INPUT TYPE="SUBMIT" VALUE="Login"></TD>
		</TR></TABLE>',
		$I{query}->endform,
		"</CENTER>\n<!-- end admin login form -->\n";
}

##################################################################
#  Variables Editor
sub varEdit {
	my($name) = @_;
	print qq[\n<!-- begin variables editor form -->\n<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">\n];
	selectGeneric('vars', 'name', 'name', 'name', $name);
	my($value, $desc) = sqlSelect('value,description',
		'vars', "name='$name'");
	print "Next<BR>\n",
		formLabel('Variable Name'),
		$I{query}->textfield(-name => 'thisname', -default => $name),
		formLabel('Value'),
		$I{query}->textfield(-name => 'value',-default => $value),
		formLabel('Description'),
		$I{query}->textfield(-name => 'desc', -default => $desc, -size => 60),
		qq'<INPUT TYPE="SUBMIT" VALUE="varsave" NAME="op">
		</FORM><!-- end variables editor form -->\n';
}

##################################################################
sub varSave {
	if ($I{F}{thisname}) {
		my($exists) = sqlSelect('count(*)', 'vars',
			"name='$I{F}{thisname}'"
		);

		if ($exists == 0) {
			sqlInsert('vars', { name => $I{F}{thisname} });
			print "Inserted $I{F}{thisname}<BR>\n";
		}
		if($I{F}{desc}) {
			print "Saved $I{F}{thisname}<BR>\n";
			sqlUpdate("vars", {
					value => $I{F}{value},
					description => $I{F}{desc}
				}, "name=" . $I{dbh}->quote($I{F}{thisname})
			);
		} else {
			print "<B>Deleted $I{F}{thisname}!</B><BR>\n";
			$I{dbh}->do("DELETE from vars WHERE name='$I{F}{thisname}'");
		}
	}
}

##################################################################
# Author Editor
sub authorEdit {
	my ($aid) = @_;

	$aid ||= $I{U}{aid};
	$aid = '' if $I{F}{authornew};

	my ($name,$url,$email,$quote,$copy,$pwd,$seclev,$section); 

	print qq!<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">!;
	selectGeneric('authors', 'myaid', 'aid', 'aid', $aid);
	
	if($aid) {	
		($name,$url,$email,$quote,$copy,$pwd,$seclev,$section) = 
		sqlSelect('name,url,email,quote,copy,pwd,seclev,section', 'authors','aid ='. $I{dbh}->quote($aid)); 
	}

	for ($quote, $copy) {
		$_ = stripByMode($_, 'literal');
	}

	print <<EOT;
<INPUT TYPE="submit" VALUE="Select Author" NAME="authoredit"><BR>
<TABLE BORDER="0">
	<TR>
		<TD>Aid</TD><TD><INPUT TYPE="text" NAME="thisaid" VALUE="$aid"></TD>
	</TR>
	<TR>
		<TD>Name</TD><TD><INPUT TYPE="text" NAME="name" VALUE="$name"></TD>
	</TR>
	<TR>
		<TD>URL</TD><TD><INPUT TYPE="text" NAME="url" VALUE="$url"></TD>
	</TR>
	<TR>
		<TD>Email</TD><TD><INPUT TYPE="text" NAME="email" VALUE="$email"></TD>
	</TR>
	<TR>
		<TD>Quote</TD><TD><TEXTAREA NAME="quote" COLS="50" ROWS="4">$quote</TEXTAREA></TD>
	</TR>
	<TR>
		<TD>Copy</TD><TD><TEXTAREA NAME="copy" COLS="50" ROWS="5">$copy</TEXTAREA></TD>
	</TR>
	<TR>
		<TD>Passwd</TD><TD><INPUT TYPE="password" NAME="pwd" VALUE="$pwd"></TD>
	</TR>
	<TR>
		<TD>Seclev</TD><TD><INPUT TYPE="text" NAME="seclev" VALUE="$seclev"></TD>
	</TR>
</TABLE>
		Restrict to Section
EOT

	selectSection('section', $section) ;

	print <<EOT;
<TABLE BORDER="0">
	<TR>
		<TD><BR><INPUT TYPE="SUBMIT" VALUE="Save Author" NAME="authorsave"></TD>
EOT
	print <<EOT if ! $I{F}{authornew};
		<TD><BR><INPUT TYPE="SUBMIT" VALUE="Create Author" NAME="authornew"></TD>
EOT
	print <<EOT if (! $I{F}{authornew} && $aid ne $I{U}{aid}) ;
		<TD><BR><INPUT TYPE="SUBMIT" VALUE="Delete Author" NAME="authordelete"></TD>
EOT

print qq|\t</TR>\n</TABLE>\n</FORM>\n|;

}

##################################################################
sub authorSave {
	if ($I{F}{thisaid}) {
		my($exists) = sqlSelect('count(*)', 'authors',
			'aid=' . $I{dbh}->quote($I{F}{thisaid})
		);

		if (!$exists) {
			sqlInsert('authors', { aid => $I{F}{thisaid}});
			print "Inserted $I{F}{thisaid}<BR>";
		}
		if ($I{F}{thisaid}) {
			print "Saved $I{F}{thisaid}<BR>";
			sqlUpdate('authors',{
					name	=> $I{F}{name},
					pwd	=> $I{F}{pwd},
					email	=> $I{F}{email},
					url	=> $I{F}{url},
					seclev	=> $I{F}{seclev},
					copy	=> $I{F}{copy},
					quote	=> $I{F}{quote},
					section => $I{F}{section}
				}, 'aid=' . $I{dbh}->quote($I{F}{thisaid})
			);
		} else {
			print "<B>Deleted $I{F}{thisaid}!</B><BR>";
			$I{dbh}->do('DELETE from authors WHERE aid='
				. $I{dbh}->quote($I{F}{thisaid})
			);
		}
	}
}

##################################################################
sub authorDelete {
		my $aid = shift;

	print qq|<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">|;
	print <<EOT if $I{F}{authordelete};
		<B>Do you really want to delete $aid?</B><BR> 
		<INPUT TYPE="HIDDEN" VALUE="$aid" NAME="thisaid">
		<INPUT TYPE="SUBMIT" VALUE="Cancel delete $aid" NAME="authordelete_cancel">
		<INPUT TYPE="SUBMIT" VALUE="Delete $aid" NAME="authordelete_confirm">
EOT
		if ($I{F}{authordelete_confirm}) {
			$I{dbh}->do('DELETE from authors WHERE aid=' . $I{dbh}->quote($aid));
			print "<B>Deleted $aid!</B><BR>" if ! DBI::errstr;
		}
		elsif($I{F}{authordelete_cancel}) {
			print "<B>Canceled Deletion of $aid!</B><BR>";
		}
}
##################################################################
# Block Editing and Saving 
# 020300 PMG modified the heck out of this code to allow editing
# of sectionblock values retrieve, title, url, rdf, section 
# to display a different form according to the type of block we're dealing with
# based on value of new column in blocks "type". Added description field to use 
# as information on the block to help the site editor get a feel for what the block 
# is for, etc... 
sub blockEdit {
	my($seclev, $bid) = @_;

	return if $seclev < 500;
	my($hidden_bid) = "";
	my($title,$url,$rdf,$ordernum,$retrieve,$section,$portal,$saveflag,$isabid);

        titlebar("100%","Site Block Editor","c");

	print <<EOT;
<!-- begin block editing form -->
<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
EOT

	if(! $I{F}{blockdelete} && ! $I{F}{blockdelete1} && ! $I{F}{blockdelete2}) {
		print <<EOT;
<P>Select a block to edit. 
<UL>
	<LI>You can only edit static blocks.</LI> 
	<LI>Blocks that are portald type blocks are written by portald</LI>
</UL>
</P>
<TABLE>
	<TR>
		<TD><B>Static Blocks</B></TD><TD>
EOT

		# get the static blocks
		selectGeneric('blocks', 'bid1', 'bid', 'bid', $bid, "$seclev >= seclev and type != 'portald'");
		print qq[</TD><TD><INPUT TYPE="SUBMIT" VALUE="Edit Block" NAME="blocked1"></TD>
		<TD><INPUT TYPE="SUBMIT" VALUE="Delete Block" NAME="blockdelete1"></TD>\n\t</TR>\n];
		# get the portald blocks
		print qq[\t<TR><TD><B>Portald Blocks</B></TD><TD>];
		selectGeneric('blocks', 'bid2', 'bid', 'bid', $bid, "$seclev >= seclev and type = 'portald'");
		print qq[</TD><TD><INPUT TYPE="SUBMIT" VALUE="Edit Block" NAME="blocked2"></TD>
		<TD><INPUT TYPE="SUBMIT" VALUE="Delete Block" NAME="blockdelete2"></TD>\n\t</TR>\n</TABLE>\n];
	}


	if($I{F}{blockdelete} || $I{F}{blockdelete1} || $I{F}{blockdelete2}) {
		print <<EOT;
<INPUT TYPE="HIDDEN" NAME="deletebid" VALUE="$bid">
<TABLE BORDER="0">
	<TR>
		<TD><B>Do you really want to delete Block $bid?</B></TD>
		<TD><INPUT TYPE="SUBMIT" VALUE="Cancel Delete of $bid" NAME="blockdelete_cancel"></TD>
		<TD><INPUT TYPE="SUBMIT" VALUE="Really Delete $bid!" NAME="blockdelete_confirm"></TD>
	</TR>
</TABLE>
EOT
	}

	# if the pulldown has been selected and submitted 
	# or this is a block save and the block is a portald block
	# or this is a block edit via sections.pl
	if (! $I{F}{blocknew} && $bid ) {
		($isabid,$title,$url,$rdf,$ordernum,$retrieve,$section,$portal) = sqlSelect('bid,title,url,rdf,ordernum,retrieve,section,portal', 'sectionblocks', "bid='$bid'");
		if ($isabid) {
			$title = qq[<TR>\n\t\t<TD><B>Title</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="70" NAME="title" VALUE="$title"></TD>\n\t</TR>];
			$url = qq[<TR>\n\t\t<TD><B>URL</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="70" NAME="url" VALUE="$url"></TD>\n\t</TR>];
			$rdf = qq[<TR>\n\t\t<TD><B>RDF</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="70" NAME="rdf" VALUE="$rdf"></TD>\n\t</TR>];
			$section = qq[<TR>\n\t\t<TD><B>Section</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="10" NAME="section" VALUE="$section"></TD>\n\t</TR>];
			$ordernum = "NA" if $ordernum eq '';
			$ordernum = qq[<TR>\n\t\t<TD><B>Ordernum</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="3" NAME="ordernum" VALUE="$ordernum"></TD>\n\t</TR>];
			my $checked = "CHECKED" if $retrieve == 1; 
			$retrieve = qq[<TR>\n\t\t<TD><B>Retrieve</B></TD><TD COLSPAN="2"><INPUT TYPE="CHECKBOX" VALUE="1" NAME="retrieve" $checked></TD>\n\t</TR>];
			$checked = "";
			$checked = "CHECKED" if $portal == 1; 
			$portal = qq[<TR>\n\t\t<TD><B>Portal - check if this is a slashbox.</B></TD><TD COLSPAN="2"><INPUT TYPE="CHECKBOX" VALUE="1" NAME="portal" $checked></TD>\n\t</TR>];
			$saveflag = qq[<INPUT TYPE="HIDDEN" NAME="save_existing" VALUE="1">];
			$checked = "";
		}	
	}	
	# if this is a new block, we want an empty form 
	else {
		$title = qq[<TR>\n\t\t<TD><B>Title</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="70" NAME="title" VALUE=""></TD>\n\t</TR>];
		$url = qq[<TR>\n\t\t<TD><B>URL</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="70" NAME="url" VALUE=""></TD>\n\t</TR>];
		$rdf = qq[<TR>\n\t\t<TD><B>RDF</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="70" NAME="rdf" VALUE=""></TD>\n\t</TR>];
		$section = qq[<TR>\n\t\t<TD><B>Section</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="10" NAME="section" VALUE=""></TD>\n\t</TR>];
		$ordernum = qq[<TR>\n\t\t<TD><B>Ordernum</B></TD><TD COLSPAN="2"><INPUT TYPE="TEXT" SIZE="3" NAME="ordernum" VALUE=""></TD>\n\t</TR>];
		$retrieve = qq[<TR>\n\t\t<TD><B>Retrieve</B></TD><TD COLSPAN="2"><INPUT TYPE="CHECKBOX" VALUE="1" NAME="retrieve"></TD>\n\t</TR>];
		$portal = qq[<TR>\n\t\t<TD><B>Portal - check if this is a slashbox. </B></TD><TD COLSPAN="2"><INPUT TYPE="CHECKBOX" VALUE="1" NAME="portal"></TD>\n\t</TR>];
		$saveflag = qq[<INPUT TYPE="HIDDEN" NAME="save_new" VALUE="1">];
	}

	my($block, $bseclev, $type, $description) =
		sqlSelect('block,seclev,type,description', 'blocks', "bid='$bid'") if $bid;

	my $description_ta = stripByMode($description, 'literal');
	$block = stripByMode($block, 'literal');

	# main table
	print <<EOT;
<TABLE BORDER="0">
EOT
	# if there's a block description, print it
	print <<EOT if ($description);
	<TR>
		<TD COLSPAN="3">
		<TABLE BORDER="2" CELLPADDING="4" CELLSPACING="0" BGCOLOR="$I{fg}[1]" WIDTH="80%">
			<TR>
				<TD BGCOLOR="$I{bg}[2]"><BR><B>Block ID: $bid</B><BR>
				<P>$description</P><BR>
				</TD>
			</TR>
		</TABLE>
		<BR>
		</TD>
	</TR>
EOT

# print the form if this is a new block, submitted block, or block edit via sections.pl
	print <<EOT if ( (! $I{F}{blockdelete_confirm} && $bid) || $I{F}{blocknew}) ;
	<TR>	
		<TD><B>Block ID</B></TD>
		<TD><INPUT TYPE="TEXT" NAME="thisbid" VALUE="$bid"></TD>
	</TR>
		$title
	<TR>	
		<TD><B>Seclev</B></TD><TD><INPUT TYPE="TEXT" NAME="bseclev" VALUE="$bseclev" SIZE="6"></TD>
	</TR>
	<TR>	
		<TD><B>Type</B></TD><TD><INPUT TYPE="TEXT" NAME="type" VALUE="$type" SIZE="10"></TD>
	</TR>
		$section
		$ordernum
		$portal
		$retrieve
		$url
		$rdf
		$saveflag
	<TR>
		<TD VALIGN="TOP"><B>Description</B></TD>
		<TD ALIGN="left" COLSPAN="2">
		<TEXTAREA ROWS="6" COLS="70" NAME="description">$description_ta</TEXTAREA>
		</TD>
	</TR>
	<TR>	
		<TD VALIGN="TOP"><B>Block</B><BR>
		<P>
			<INPUT TYPE="SUBMIT" VALUE="Save Block" NAME="blocksave"><BR>
			<INPUT TYPE="SUBMIT" NAME="blockrevert" VALUE="Revert to default">
			<BR><INPUT TYPE="SUBMIT" NAME="blocksavedef" VALUE="Save as default">
			(Make sure this is what you want!)
		</P>
		</TD>
		<TD ALIGN="left" COLSPAN="2">
		<TEXTAREA ROWS="15" COLS="100" NAME="block">$block</TEXTAREA>
		</TD>
	</TR>
EOT

# print the delete button if this is anything other than 
# a new form, or initial submission from author menu
print <<EOT if (! $I{F}{blocknew} && $I{F}{blockdelete_cancel} && ! $I{F}{blockdelete} && ! $I{F}{blockdelete1} && ! $I{F}{blockdelete2});
	<TR>	
		<TD COLSPAN="3">
		<INPUT TYPE="SUBMIT" VALUE="Delete Block" NAME="blockdelete"></P>
		</TD>
	</TR>
EOT

# print the new block if this isn't already a new block
print <<EOT if (! $I{F}{blocknew});
	<TR>	
		<TD COLSPAN="3">
		<INPUT TYPE="SUBMIT" VALUE="Create a new block" NAME="blocknew"></P>
		</TD>
	</TR>
EOT

print <<EOT;
</TABLE>
</FORM>
<!-- end block editing form -->
EOT

	my $c = sqlSelectMany('section', 'sectionblocks', "bid='$bid'");
	while (my($section) = $c->fetchrow) {
		print <<EOT;
<B><A HREF="$I{rootdir}/sections.pl?section=$section&op=editsection">$section</A></B>
	(<A HREF="$I{rootdir}/users.pl?op=preview&bid=$bid">preview</A>)
EOT
	}

	$c->finish;
}

##################################################################
sub blockRevert {
	my $bid = shift;
	return if $I{U}{aseclev} < 500;

	$I{dbh}->do("update blocks set block = blockbak where bid = '$bid'");
	
}

##################################################################
sub blockSave {
	my $bid = shift;
	return if $I{U}{aseclev} < 500;
	if ($bid) {
		my ($rows) = sqlSelect('count(*)', 'blocks', 'bid=' . $I{dbh}->quote($bid)); 
	
		if ($I{F}{save_new} && $rows > 0) {
			print qq[<P><B>This block, $bid, already exists! <BR>Hit the "back" button, and try another bid (look at the blocks pulldown to see if you are using an existing one.)</P>]; 
			return;
		}	

		if ($rows == 0) {
			sqlInsert('blocks', { bid => $bid, seclev => 500 });
			sqlInsert('sectionblocks', { bid => $bid });
			print "Inserted $bid<BR>";
		}

		my ($portal,$retrieve) = (0,0);

		# this is to make sure that a  static block doesn't get
		# saved with retrieve set to true
		$I{F}{retrieve} = 0 if $I{F}{type} ne 'portald';

		print "Saved $bid<BR>";
			
		$I{F}{block} = autoUrl($I{F}{section}, $I{F}{block});

		if ($rows == 0 || $I{F}{blocksavedef}) {
			sqlUpdate('blocks', {
				seclev	=> $I{F}{bseclev}, 
				block	=> $I{F}{block},
				blockbak => $I{F}{block},
				description => $I{F}{description},
				type 	=> $I{F}{type},

				}, 'bid=' . $I{dbh}->quote($bid)
			);
		} else {
			sqlUpdate('blocks', {
				seclev	=> $I{F}{bseclev}, 
				block	=> $I{F}{block},
				description => $I{F}{description},
				type 	=> $I{F}{type},

				}, 'bid=' . $I{dbh}->quote($bid)
			);
		}

		sqlUpdate('sectionblocks', {
				ordernum=> $I{F}{ordernum}, 
				title 	=> $I{F}{title},
				url	=> $I{F}{url},	
				rdf	=> $I{F}{rdf},	
				section => $I{F}{section},	
				retrieve=> $I{F}{retrieve}, 
				portal => $I{F}{portal}, 
			}, 'bid=' . $I{dbh}->quote($bid)
		);

	}
}

##################################################################
sub blockDelete {
		my $bid = shift;
		return if $I{U}{aseclev} < 500;
		print "<B>Deleted $bid!</B><BR>";
		$I{dbh}->do('DELETE from blocks WHERE bid=' . $I{dbh}->quote($bid));
		$I{dbh}->do('DELETE from sectionblocks WHERE bid=' . $I{dbh}->quote($bid));
}

##################################################################
sub colorEdit {
	return if $I{U}{aseclev} < 500;

	my $colorblock;
	$I{F}{color_block} ||= 'colors';

	if($I{F}{colorpreview}) {
		$colorblock = 
		"$I{F}{fg0},$I{F}{fg1},$I{F}{fg2},$I{F}{fg3},$I{F}{bg0},$I{F}{bg1},$I{F}{bg2},$I{F}{bg3}";

		my $colorblock_clean = $colorblock;
		# the #s will break the url 
		$colorblock_clean =~ s/#//g;
		print <<EOT
	<br>
	<a href="$I{rootdir}/index.pl?colorblock=$colorblock_clean">
	<p><b>Click here to see the site in these colors!</a></b> 
	 (Hit the <b>"back"</b> button to get back to this page.)</p>
	
EOT
	} else {
		($colorblock) = sqlSelect('block', 'blocks', "bid='$I{F}{color_block}'"); 
	}

	my @colors = split m/,/, $colorblock;

	$I{fg} = [@colors[0..3]];
	$I{bg} = [@colors[4..7]];
	print "<P>You may need to reload the page a couple of times to see a change in the color scheme.
		<BR>If you can restart the webserver, that's the quickest way to see your changes.</P>";

       	titlebar("100%","Site Color Editor","c");
	print <<EOT;
<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
<P>Shown are the site colors. If you make a change to any one of them, 
you will need to restart the webserver for the change(s) to show up.</P>
<P>Note: make sure you use a valid color value, or the color will not work properly.</P>
Select the color block to edit: 
EOT
	selectGeneric('blocks', 'color_block', 'bid', 'bid', $I{F}{color_block}, "type = 'color'");

print <<EOT;
	<INPUT TYPE="submit" name="colored" value="Edit Colors">
EOT

print <<EOT if $I{F}{color_block};
<TABLE BORDER="0">
	<TR>
		<TD>Foreground color 0 \$I{fg}[0]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="fg0" VALUE="$colors[0]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[0]">Foreground color 0 \$I{fg}[0]</FONT></TD>
		<TD BGCOLOR="$colors[0]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD>Foreground color 1 \$I{fg}[1]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="fg1" VALUE="$colors[1]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[1]">Foreground color 1 \$I{fg}[1]</FONT></TD>
		<TD BGCOLOR="$colors[1]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD>Foreground color 2 \$I{fg}[2]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="fg2" VALUE="$colors[2]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[2]">Foreground color 2 \$I{fg}[2]</FONT></TD>
		<TD BGCOLOR="$colors[2]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD>Foreground color 3 \$I{fg}[3]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="fg3" VALUE="$colors[3]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[3]">Foreground color 3 \$I{fg}[3]</FONT></TD>
		<TD BGCOLOR="$colors[3]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TD>
	<TR>
		<TD>Background color 0 \$I{bg}[0]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="bg0" VALUE="$colors[4]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[4]">Background color 0 \$I{bg}[0]</FONT></TD>
		<TD BGCOLOR="$colors[4]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD>Background color 1 \$I{bg}[1]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="bg1" VALUE="$colors[5]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[5]">Background color 1 \$I{fg}[1]</FONT></TD>
		<TD BGCOLOR="$colors[5]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TD>
	<TR>
		<TD>Background color 2 \$I{bg}[2]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="bg2" VALUE="$colors[6]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[6]">Background color 2 \$I{fg}[2]</FONT></TD>
		<TD BGCOLOR="$colors[6]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD>Background color 3 \$I{bg}[3]</TD>
		<TD><INPUT TYPE="TEXT" WIDTH="12" NAME="bg3" VALUE="$colors[7]"></TD>
		<TD><FONT FACE="ARIAL,HELVETICA" SIZE="+1" COLOR="$colors[7]">Background color 3 \$I{fg}[3]</FONT></TD>
		<TD BGCOLOR="$colors[7]">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
	</TR>
	<TR>
		<TD><INPUT TYPE="SUBMIT" NAME="colorpreview" VALUE="Preview"></TD>
		<TD><INPUT TYPE="SUBMIT" NAME="colorsave" VALUE="Save Colors"></TD>
		<TD><INPUT TYPE="SUBMIT" NAME="colorrevert" VALUE="Revert to saved"></TD>
		<TD><INPUT TYPE="SUBMIT" NAME="colororig" VALUE="Revert to default">
		<BR><INPUT TYPE="SUBMIT" NAME="colorsavedef" VALUE="Save as default">
		 (Make sure this is what you want!) 
		</TD>
	</TR>
</TABLE>
</FORM>
EOT
}
##################################################################
sub colorSave {
	return if $I{U}{aseclev} < 500;
	my $colorblock = 
	"$I{F}{fg0},$I{F}{fg1},$I{F}{fg2},$I{F}{fg3},$I{F}{bg0},$I{F}{bg1},$I{F}{bg2},$I{F}{bg3}";

	$I{F}{color_block} ||= 'colors';

	if($I{F}{colorsave}) {
		# save into colors and colorsback
		sqlUpdate('blocks', {
				block => $colorblock, 
			}, "bid = '$I{F}{color_block}'"
		);
		
	}
	elsif($I{F}{colorsavedef}) {
		# save into colors and colorsback
		sqlUpdate('blocks', {
				block => $colorblock, 
				blockbak => $colorblock, 
			}, "bid = '$I{F}{color_block}'"
		);
		
	}
	elsif($I{F}{colororig}) {
		# reload original version of colors
		$I{dbh}->do("update blocks set block = blockbak where bid = '$I{F}{color_block}'");
	}
		
}
##################################################################
# Topic Editor
sub topicEd {
	return if $I{U}{aseclev} < 1;
	my ($tid, $width, $height, $alttext, $image, @available_images);

	opendir(DIR,"$I{basedir}/images/topics");
	@available_images = grep(!/^\./, readdir(DIR)); 
	closedir(DIR);

	print <<EOT;
<!-- begin topic editor form -->
<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
EOT

	selectGeneric('topics', 'nexttid', 'tid', 'tid', $I{F}{nexttid});

	print '<INPUT TYPE="SUBMIT" NAME="topiced" VALUE="Select topic"><BR>';
	print '<INPUT TYPE="SUBMIT" NAME="topicnew" VALUE="Create new topic"><BR>';

	if(! $I{F}{topicdelete}) {
		if(! $I{F}{topicnew}) {
			($tid, $width, $height, $alttext, $image) = 
			sqlSelect( 'tid,width,height,alttext,image', 'topics', "tid='$I{F}{nexttid}'");
		} else {
			($tid, $width, $height, $alttext, $image) = ('new topic','','','','');
		}

		print qq'<BR>Image as seen: <BR><BR><IMG SRC="$I{imagedir}/topics/$image" ALT="$alttext" WIDTH="$width" HEIGHT="$height">'
			if ( $I{F}{nexttid} && ! $I{F}{topicnew} && ! $I{F}{topicdelete});

		print <<EOT;
		<BR><BR>Tid<BR><INPUT TYPE="TEXT" NAME="tid" VALUE="$tid"><BR>
		<BR>Dimensions (leave blank to determine automatically)<BR>
		Width: <INPUT TYPE="TEXT" NAME="width" VALUE="$width" SIZE="4">
		Height: <INPUT TYPE="TEXT" NAME="height" VALUE="$height" SIZE="4"><BR>
		<BR>Alt Text<BR>
		<INPUT TYPE="TEXT" NAME="alttext" VALUE="$alttext"><BR>
		<BR>Image<BR>
EOT

		if (@available_images) {
			print qq|<SELECT name="image">|;
			qq|<OPTION value="">Select an image</OPTION>| if $I{F}{topicnew};
			for(@available_images) {
				my ($selected);
				$selected = "SELECTED" if ($_ eq $image);
				print qq|<OPTION value="$_" $selected>$_</OPTION>\n|;
				$selected = '';
			}
			print '</SELECT>';
		} else {
			# If we don't have images in the proper place, print a message
			# and use a regular text input field.
			print <<EOT;
<P>No images were found in the topic images directory (&lt;basedir&gt;/images/topics).<BR>
<INPUT TYPE="TEXT" NAME="image" VALUE="$image"><BR><BR>
EOT
		}

		print <<EOT;
			<INPUT TYPE="SUBMIT" NAME="topicsave" VALUE="Save Topic">
			<INPUT TYPE="SUBMIT" NAME="topicdelete" VALUE="Delete Topic">
EOT
	}

print qq|</FORM>\n<!-- end topic editor form -->\n|;




}

##################################################################
sub topicDelete {
		my $tid = shift || $I{F}{tid};
		print "<B>Deleted $tid!</B><BR>";
		$I{dbh}->do('DELETE from topics WHERE tid=' . $I{dbh}->quote($tid));
		$I{F}{tid} = '';
}

##################################################################
sub topicSave {
	if ($I{F}{tid}) {
		my($rows) = sqlSelect('count(*)', 'topics', 'tid=' . $I{dbh}->quote($I{F}{tid}));
		if (!$I{F}{width} && !$I{F}{height}) {
		    @{ $I{F} }{'width', 'height'} = imgsize("$I{basedir}/images/topics/$I{F}{image}");
		}
		if($rows == 0 ) {
			sqlInsert('topics', {
				tid	=> $I{F}{tid},
				image	=> $I{F}{image},
				alttext	=> $I{F}{alttext},
				width	=> $I{F}{width},
				height	=> $I{F}{height}
			}
			);
		}

		sqlUpdate('topics', {
				image	=> $I{F}{image}, 
				alttext	=> $I{F}{alttext}, 
				width	=> $I{F}{width},
				height	=> $I{F}{height}
			}, 'tid=' . $I{dbh}->quote($I{F}{tid})
		);
	}
	print "<B>Saved $I{F}{tid}!</B><BR>" if ! DBI::errstr;
	$I{F}{nexttid} = $I{F}{tid};
}
##################################################################
sub listtopics {
	my($seclev) = @_;
	my $cursor = $I{dbh}->prepare('SELECT tid,image,alttext,width,height
					FROM topics
					ORDER BY tid');
	titlebar('100%', 'Topic Lister');

	my $x = 0;
	$cursor->execute;

	print qq[\n<!-- begin listtopics -->\n<TABLE WIDTH="600" ALIGN="CENTER">];
	while (my($tid, $image, $alttext, $width, $height) = $cursor->fetchrow) {
		if ($x == 0) {
			print "<TR>\n";
		} elsif ($x++ % 6) {
			print "</TR><TR>\n";
		}
		print qq!\t<TD ALIGN="CENTER">\n!;

		if ($seclev > 500) {
			print qq[\t\t<A HREF="$ENV{SCRIPT_NAME}?op=topiced&nexttid=$tid">];
		} else {
			print qq[\t\t<A NAME="">];
		}

		print qq[<IMG SRC="$I{imagedir}/topics/$image" ALT="$alttext"
			WIDTH="$width" HEIGHT="$height" BORDER="0"><BR>$tid</A>\n\t</TD>\n];

	}
	$cursor->finish();
	print "</TR></TABLE>\n<!-- end listtopics -->\n";
}

##################################################################
# autoUrl & Helper Functions
# Image Importing, Size checking, File Importing etc
sub getUrlFromTitle {
	my($title) = @_;
	my($section, $sid) = sqlSelect('section,sid', 'stories',
		qq[title like "\%$title%"],
		'order by time desc LIMIT 1'
	);
	return "$I{rootdir}/article.pl?sid=$sid";
}

##################################################################
sub importImage {
	# Check for a file upload
	my $section = $_[0];
 	my $filename = $I{query}->param('importme');
	my $tf = getsiddir() . $filename;
	$tf =~ s|/|~|g;
	$tf = "$section~$tf";

	if ($filename) {
		local *IMAGE;
		system("mkdir /tmp/slash");
		open(IMAGE, ">>/tmp/slash/$tf");
		my $buffer;
		while (read $filename, $buffer, 1024) {
			print IMAGE $buffer;
		}
		close IMAGE;
	} else {
		return "<image:not found>";
	}

	use imagesize;
	my($w, $h) = imagesize::imagesize("/tmp/slash/$tf");
	return qq[<IMG SRC="$I{rootdir}/$section/] .  getsiddir() . $filename
		. qq[" WIDTH="$w" HEIGHT="$h" ALT="$section">];
}

##################################################################
sub importFile {
	# Check for a file upload
	my $section = $_[0];
 	my $filename = $I{query}->param('importme');
	my $tf = getsiddir() . $filename;
	$tf =~ s|/|~|g;
	$tf = "$section~$tf";

	if ($filename) {
		system("mkdir /tmp/slash");
		open(IMAGE, ">>/tmp/slash/$tf");
		my $buffer;
		while (read $filename, $buffer, 1024) {
			print IMAGE $buffer;
		}
		close IMAGE;
	} else {
		return "<attach:not found>";
	}
	return qq[<A HREF="$I{rootdir}/$section/] . getsiddir() . $filename
		. qq[">Attachment</A>];
}

##################################################################
sub importText {
	# Check for a file upload
 	my $filename = $I{query}->param('importme');
	my($r, $buffer);
	if ($filename) {
		while (read $filename, $buffer, 1024) {
			$r .= $buffer;
		}
	}
	return $r;
}

##################################################################
sub linkNode {
	my $n = shift;
	return $n . '<SUP><A HREF="http://www.everything2.com/index.pl?node='
		. $I{query}->escape($n) . '">[?]</A></SUP>';
}

##################################################################
sub autoUrl {
	my($section) = shift;
	local $_ = join ' ', @_;

	s/([0-9a-z])\?([0-9a-z])/$1'$2/gi if $I{F}{fixquotes};
	s/\[(.*?)\]/linkNode($1)/ge if $I{F}{autonode};
	
	my $initials = substr $I{U}{aid}, 0, 1;
	my $more = substr $I{U}{aid}, 1;
	$more =~ s/[a-z]//g;
	$initials = uc($initials . $more);
	my($now) = sqlSelect('date_format(now(),"m/d h:i p")');

	# Assorted Automatic Autoreplacements for Convenience
	s|<disclaimer:(.*)>|<B><A HREF="/about.shtml#disclaimer">disclaimer</A>:<A HREF="$I{U}{url}">$I{U}{aid}</A> owns shares in $1</B>|ig;
	s|<update>|<B>Update: <date></B> by <author>|ig;
	s|<date>|$now|g;
	s|<author>|<B><A HREF="$I{U}{url}">$initials</A></B>:|ig;
	s/\[%(.*?)%\]/getUrlFromTitle($1)/exg;

	# Assorted ways to add files:
	s|<import>|importText()|ex;
	s/<image(.*?)>/importImage($section)/ex;
	s/<attach(.*?)>/importFile($section)/ex;
	return $_;
}

##################################################################
# Generated the 'Related Links' for Stories
sub getRelated {
	my %relatedLinks = (
		intel		=> "Intel;http://www.intel.com",
		linux		=> "Linux;http://www.linux.com",
		lycos		=> "Lycos;http://www.lycos.com",
		redhat		=> "Red Hat;http://www.redhat.com",
		'red hat'	=> "Red Hat;http://www.redhat.com",
		wired		=> "Wired;http://www.wired.com",
		netscape	=> "Netscape;http://www.netscape.com",
		lc $I{sitename}	=> "$I{sitename};$I{rootdir}",
		malda		=> "Rob Malda;http://CmdrTaco.net",
		cmdrtaco	=> "Rob Malda;http://CmdrTaco.net",
		apple		=> "Apple;http://www.apple.com",
		debian		=> "Debian;http://www.debian.org",
		zdnet		=> "ZDNet;http://www.zdnet.com",
		'news.com'	=> "News.com;http://www.news.com",
		cnn		=> "CNN;http://www.cnn.com"
	);


	local($_) = @_;
	my $r;
	foreach my $key (keys %relatedLinks) {
		if (exists $relatedLinks{$key} && /\W$key\W/i) {
			my($t,$u) = split m/;/, $relatedLinks{$key};
			$t =~ s/(\S{20})/$1 /g;
			$r .= qq[<LI><A HREF="$u">$t</A></LI>\n];
		}
	}

	# And slurp in all the URLs just for good measure
	while (m|<A(.*?)>(.*?)</A>|sgi) {
		my($u, $t) = ($1, $2);
		$t =~ s/(\S{30})/$1 /g;
		$r .= "<LI><A$u>$t</A></LI>\n" unless $t eq "[?]";
	}
	return $r;
}

##################################################################
sub otherLinks {
	my $aid = shift;
	my $tid = shift;

	my $T = getTopic($tid);

	return <<EOT;
<LI><A HREF="$I{rootdir}/search.pl?topic=$tid">More on $T->{alttext}</A></LI>
<LI><A HREF="$I{rootdir}/search.pl?author=$aid">Also by $aid</A></LI>
EOT

}

##################################################################
# Story Editing
sub editstory {
	my($sid) = @_;
	my($S, $A, $T);

	foreach (keys %{$I{F}}) { $S->{$_} = $I{F}{$_} }

	my $newarticle = 1 if !$sid && !$I{F}{sid};
	
	print <<EOT;

<!-- begin editstory -->

<FORM ENCTYPE="multipart/form-data" ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
EOT

	if ($I{F}{title}) { 
		# Preview Mode
		print qq!<INPUT TYPE="HIDDEN" NAME="subid" VALUE="$I{F}{subid}">!
			if $I{F}{subid};

		sqlUpdate('sessions', { lasttitle => $S->{title} },
			'aid=' . $I{dbh}->quote($I{U}{aid})
		);

		($S->{writestatus}, $S->{displaystatus}, $S->{commentstatus}) =
			getvars('defaultwritestatus','defaultdisplaystatus',
			'defaultcommentstatus');

		$S->{aid} ||= $I{U}{aid};
		$S->{section} = $I{F}{section};

		my @extracolumns = sqlSelectColumns($S->{section}) 
			if sqlTableExists($S->{section});

		foreach (@extracolumns) {
			$S->{$_} = $I{F}{$_} || $S->{$_};
		}

		$S->{writestatus} = $I{F}{writestatus} if exists $I{F}{writestatus};
		$S->{displaystatus} = $I{F}{displaystatus} if exists $I{F}{displaystatus};
		$S->{commentstatus} = $I{F}{commentstatus} if exists $I{F}{commentstatus};
		$S->{dept} =~ s/ /-/gi;

		$S->{introtext} = autoUrl($I{F}{section}, $S->{introtext});
		$S->{bodytext} = autoUrl($I{F}{section}, $S->{bodytext});

		$T = getTopic($S->{tid});
		$I{F}{aid} ||= $I{U}{aid};
		$A = getAuthor($I{F}{aid});
		$sid = $I{F}{sid};

		$S->{sqltime} = $I{F}{'time'};
		($S->{sqltime}) = sqlSelect('now()') if !$I{F}{'time'} || $I{F}{fastforward};

		print '<TABLE><TR><TD>';
		my $tmp = $I{currentSection};
		$I{currentSection} = $S->{section};
		dispStory($S, $A, $T, 'Full');
		$I{currentSection} = $tmp;
		print '</TD><TD WIDTH="210" VALIGN="TOP">';
		$S->{relatedtext} = getRelated("$S->{title} $S->{bodytext} $S->{introtext}")
			. otherLinks($S->{aid}, $S->{tid});

		fancybox(200, 'Related Links', $S->{relatedtext});
		$I{query}->param('relatedtext', $S->{relatedtext});
		$I{query}->hidden('relatedtext');

		print <<EOT;
</TD></TR></TABLE>

<P><IMG SRC="$I{imagedir}/greendot.gif" WIDTH="80%" ALIGN="CENTER" HSPACE="20" HEIGHT="1"></P>

EOT

	} elsif (defined $sid) { # Loading an Old SID
		print '<TABLE><TR><TD>';
		my $tmp = $I{currentSection};
		($I{currentSection}) = sqlSelect('section', 'stories', "sid='$sid'");
		($S, $A, $T) = displayStory($sid, 'Full');
		$I{currentSection} = $tmp;
		print '</TD><TD WIDTH="220" VALIGN="TOP">';

		fancybox(200,'Related Links', $S->{relatedtext});
		$I{query}->param('relatedtext', $S->{relatedtext});

		print '</TD></TR></TABLE>';

	} else { # New Story
		($S->{writestatus}) = getvars('defaultwritestatus');
		($S->{displaystatus}) = getvars('defaultdisplaystatus');
		($S->{commentstatus}) = getvars('defaultcommentstatus');

		($S->{sqltime}) = sqlSelect('now()');
		$S->{tid} ||= 'news';
		$S->{section} ||= 'articles';
		$S->{aid} = $I{U}{aid};
	}

	my @extracolumns = sqlSelectColumns($S->{section})
		if sqlTableExists($S->{section});

	$S->{introtext} = stripByMode($S->{introtext}, 'literal');
	$S->{bodytext} = stripByMode($S->{bodytext}, 'literal');
	my $SECT = getSection($S->{section});

	print '<TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0">';
	print qq!<TR><TD BGCOLOR="$I{bg}[3]">&nbsp; </TD><TD BGCOLOR="$I{bg}[3]"><FONT COLOR="$I{fg}[3]">!;
	editbuttons($newarticle);
	selectTopic('tid', $S->{tid});
	unless ($I{U}{asection}) {
		selectSection('section', $S->{section}, $SECT) unless $I{U}{asection};
	}
	print qq!\n<INPUT TYPE="HIDDEN" NAME="writestatus" VALUE="$S->{writestatus}">!;

	if ($I{U}{aseclev} > 100 and $S->{aid}) {
		selectGeneric('authors', 'aid', 'aid', 'name', $S->{aid});
	} elsif ($S->{aid}) {
		print qq!\n<INPUT TYPE="HIDDEN" NAME="aid" VALUE="$S->{aid}">!;
	}

	# print qq!\n<INPUT TYPE="HIDDEN" NAME="aid" VALUE="$S->{aid}">! if $S->{aid};
	print qq!\n<INPUT TYPE="HIDDEN" NAME="sid" VALUE="$S->{sid}">! if $S->{sid};

	print '</FONT></TD></TR>';


	$S->{dept} =~ s/ /-/gi;
	print qq!<TR><TD BGCOLOR="$I{bg}[3]"><FONT COLOR="$I{fg}[3]"> <B>Title</B> </FONT></TD>\n<TD BGCOLOR="$I{bg}[2]"> !,
		$I{query}->textfield(-name => 'title', -default => $S->{title}, -size => 50),
		'</TD></TR>';

	if ($I{use_dept}) {
		print qq!<TR><TD BGCOLOR="$I{bg}[3]"><FONT COLOR="$I{fg}[3]"> <B>Dept</B> </FONT></TD>\n!,
			qq!<TD BGCOLOR="$I{bg}[2]"> !,
			$I{query}->textfield(-name => 'dept', -default => $S->{dept}, -size => 50),
			qq!</TD></TR>\n!;
	}

	print qq!<TR><TD BGCOLOR="$I{bg}[3]">&nbsp; </TD>\n!,
		qq!<TD BGCOLOR="$I{bg}[2]"><FONT COLOR="$I{fg}[2]">!,
		lockTest($S->{title});

	# selectForm("statuscodes","writestatus",$S->{writestatus});
	unless ($I{U}{asection}) {
		selectForm('displaycodes', 'displaystatus', $S->{displaystatus});
	}
	selectForm('commentcodes', 'commentstatus', $S->{commentstatus});

	print qq!<INPUT TYPE="TEXT" NAME="time" VALUE="$S->{sqltime}" size="16"> <BR>!;

	printf "\t[ %s | %s", $I{query}->checkbox('fixquotes'), $I{query}->checkbox('autonode');
	printf(qq! | %s | <A HREF="$I{rootdir}/pollBooth.pl?qid=$sid&op=edit">Related Poll</A>!,
		$I{query}->checkbox('fastforward')) if $sid;
	print " ]\n";

	print <<EOT;
</FONT></TD></TR></TABLE>
<BR>Intro Copy<BR>
	<TEXTAREA WRAP="VIRTUAL" NAME="introtext" COLS="70" ROWS="10">$S->{introtext}</TEXTAREA><BR>
EOT

	if (@extracolumns) {
		print <<EOT;

<TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0">
	<TR><TD ALIGN="RIGHT" COLSPAN="2" BGCOLOR="$I{bg}[3]">
		<FONT COLOR="$I{fg}[3]"> <B>Extra Data for This Section</B> </FONT>
	</TD></TR>
EOT

		foreach (@extracolumns) {
			next if $_ eq 'sid';
			my($sect, $col) = split m/_/;
			$S->{$_} = $I{F}{$_} || $S->{$_};

			printf <<EOT, $I{query}->textfield({ -name => $_, -value => $S->{$_}, -size => 64 });

	<TR><TD BGCOLOR="$I{bg}[3]">
		<FONT COLOR="$I{fg}[3]"> <B>$col</B> </FONT>
	</TD><TD BGCOLOR="$I{bg}[2]">
		<FONT SIZE="${\( $I{fontbase} + 2 )}"> %s </FONT>
	</TD></TR>
EOT

		}
		print "</TABLE>\n";
	}


	editbuttons($newarticle);
	print <<EOT;

Extended Copy<BR>
	<TEXTAREA NAME="bodytext" COLS="70" WRAP="VIRTUAL" ROWS="10">$S->{bodytext}</TEXTAREA><BR>
Import Image (don't even both trying this yet :)<BR>
	<INPUT TYPE="file" NAME="importme"><BR>

<!-- end edit story -->

EOT

	editbuttons($newarticle);
}

##################################################################
sub listStories {
	my($x, $first) = (0, $I{F}{'next'});
	my $sql = q[SELECT storiestuff.hits, commentcount, stories.sid, title, aid,
			date_format(time,"%k:%i") as t,tid,section,
			displaystatus,writestatus,
			date_format(time,"%W %M %d"),
			date_format(time,"%m/%d")
			FROM stories,storiestuff 
			WHERE storiestuff.sid=stories.sid];
	$sql .= "	AND section='$I{U}{asection}'" if $I{U}{asection};
	$sql .= "	AND section='$I{F}{section}'"  if $I{F}{section} && !$I{U}{asection};
	$sql .= "	AND time < DATE_ADD(now(), interval 72 hour) " if $I{F}{section} eq ""; 
	$sql .= "	ORDER BY time DESC";

	my $cursor = $I{dbh}->prepare($sql);
	$cursor->execute;

	my $yesterday;
	my $storiestoday = 0;

	print <<EOT;

<!-- begin liststories -->

<TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0" WIDTH="100%">
EOT

	while (my($hits, $comments, $sid, $title, $aid, $time, $tid, $section,
		$displaystatus, $writestatus, $td, $td2) = $cursor->fetchrow) {

		$x++;
		$storiestoday++;
		next if $x < $first;
		last if $x > $first + 40;

		if ($td ne $yesterday && !$I{F}{section}) {
			$storiestoday = '' unless $storiestoday > 1;
			print <<EOT;

	<TR><TD ALIGN="RIGHT" BGCOLOR="$I{bg}[2]">
		<FONT SIZE="${\( $I{fontbase} + 1 )}">$storiestoday</FONT>
	</TD><TD COLSPAN="7" ALIGN="right" BGCOLOR="$I{bg}[3]">
		<FONT COLOR="$I{fg}[3]" SIZE="${\( $I{fontbase} + 1 )}">$td</FONT>
	</TD></TR>
EOT

		    $storiestoday = 0;
		} 

		$yesterday = $td;

		if (length $title > 55) {
			$title = substr($title, 0, 50) . '...';
		}

		my $bgcolor = '';
		if ($displaystatus > 0) {
			$bgcolor = '#CCCCCC';
		} elsif ($writestatus < 0 or $displaystatus < 0) {
			$bgcolor = '#999999';
		}

		print qq[\t<TR BGCOLOR="$bgcolor"><TD ALIGN="RIGHT">\n];
		if ($I{U}{aid} eq $aid || $I{U}{aseclev} > 100) {
			$HTML::Entities::char2entity{' '} = '+';
			my($tbtitle) = encode_entities($title, '<>&" ');
			print qq!\t\t[<A HREF="$ENV{SCRIPT_NAME}?title=$tbtitle&op=edit&sid=$sid">$x</A>\n]!;

		} else {
			print "\t\t[$x]\n"
		}

		printf <<EOT, substr($tid, 0, 5);
	</TD><TD>
		<A HREF="$I{rootdir}/article.pl?sid=$sid">$title&nbsp;</A>
	</TD><TD>
		<FONT SIZE="${\( $I{fontbase} + 2 )}"><B>$aid</B></FONT>
	</TD><TD>
		<FONT SIZE="${\( $I{fontbase} + 2 )}">%s</FONT>
	</TD>
EOT

		printf <<EOT, substr($section,0,5) unless $I{U}{asection} || $I{F}{section};
	<TD>
		<FONT SIZE="${\( $I{fontbase} + 2 )}"><A HREF="$ENV{SCRIPT_NAME}?section=$section">%s</A>
	</TD>
EOT

		print <<EOT;
	<TD ALIGN="RIGHT">
		<FONT SIZE="${\( $I{fontbase} + 2 )}">$hits</FONT>
	</TD><TD>
		<FONT SIZE="${\( $I{fontbase} + 2 )}">$comments</FONT>
	</TD>
EOT

		print qq[\t<TD><FONT SIZE="${\( $I{fontbase} + 2 )}">$td2</TD>\n] if $I{F}{section};
		print qq[\t<TD><FONT SIZE="${\( $I{fontbase} + 2 )}">$time</TD></TR>\n];
	}

	my $left = $cursor->rows - $x;
	$cursor->finish;

	print "</TABLE>\n";

	if ($x > 0) {
		print <<EOT;
<P ALIGN="RIGHT"><B><A HREF="$ENV{SCRIPT_NAME}?section=$I{F}{section}&op=list&next=$x">$left More</A></B></P>
EOT
	}

	print "\n<!-- end liststories -->\n\n";
}

##################################################################
sub rmStory {
	my $sid = shift;
	sqlUpdate('stories', { writestatus => 5 }, 
		'sid=' . $I{dbh}->quote($sid)
	) if $I{U}{aseclev} > 500;

	$I{dbh}->do("DELETE from discussions WHERE sid = '$sid'");
	
	titlebar('100%', "$sid will probably be deleted in 60 seconds.");
}

##################################################################
sub listFilters {
        my $filter_hashref = sqlSelectAll("*","content_filters");
	my ($header,$footer);

	$header = getWidgetBlock('list_filters_header');
	print eval $header;

        for(@$filter_hashref) {
                print <<EOT;
        <TR>
                <TD>[<A HREF="$ENV{SCRIPT_NAME}?editfilter=1&filter_id=$_->[0]">$_->[0]</A>]</TD>
                <TD><FONT FACE="courier" size="+1">$_->[1]</FONT></TD>
                <TD> $_->[2] </TD>
                <TD> $_->[3] </TD>
                <TD> $_->[4] </TD>
                <TD> $_->[5] </TD>
                <TD> $_->[6] </TD>
                <TD> $_->[8] </TD>
                <TD> $_->[7] </TD>
        </TR>
EOT
        }

	$footer = getEvalBlock('list_filters_footer');
	print $footer;

}

##################################################################
sub editFilter {
	my $filter_id = shift;
	$filter_id ||= $I{F}{filter_id};

	print <<EOT;
<!-- begin editFilter -->
<FORM ENCTYPE="multipart/form-data" action="$ENV{SCRIPT_NAME}" method="POST">
EOT
	my($regex, $modifier, $field, $ratio, $minimum_match,
		$minimum_length, $maximum_length, $err_message) =
		sqlSelect("regex,modifier,field,ratio,minimum_match," .
			"minimum_length,maximum_length,err_message",
			"content_filters","filter_id=$filter_id");

	# this has to be here - it really screws up the block editor
	$err_message = stripByMode($err_message, 'literal');
	my $textarea = <<EOT;
<TEXTAREA NAME="err_message" COLS="50" ROWS="2">$err_message</TEXTAREA>
EOT

	my $header = getWidgetBlock('edit_filter');
	print eval $header;

	print qq|</FORM>\n<!-- end editFilter -->\n|;

}

##################################################################
sub updateFilter {
	my $filter_action = shift;

	if ($filter_action eq "new") {
		sqlInsert("content_filters", {
			regex => "",
			modifier => "",
			field => "",
			ratio => 0,
			minimum_match => 0,
			minimum_length => 0,
			maximum_length => 0,
			err_message => ""
		});

		# damn damn damn!!!! wish I could use sth->insertid !!!
		my($filter_id) = sqlSelect("max(filter_id)", "content_filters");
		titlebar("100%", "New filter# $filter_id.", "c");
		editFilter($filter_id);

	} elsif($filter_action eq "update") {
		if(! $I{F}{regex} || ! $I{F}{regex}) {
			print "<B>You haven't typed in a regex.</B><BR>\n" if ! $I{F}{regex};
			print "<B>You haven't typed in a form field.</B><BR>\n" if ! $I{F}{field};

			editFilter($I{F}{filter_id});

		} else {
			sqlUpdate("content_filters", {
				regex => $I{F}{regex},
				modifier => $I{F}{modifier},
				field => $I{F}{field},
				ratio => $I{F}{ratio},
				minimum_match => $I{F}{minimum_match},
				minimum_length => $I{F}{minimum_length},
				maximum_length => $I{F}{maximum_length},
				err_message => $I{F}{err_message},
			}, "filter_id=$I{F}{filter_id}");
		}

		titlebar("100%", "Filter# $I{F}{filter_id} saved.", "c");
		editFilter($I{F}{filter_id});
	} elsif ($filter_action eq "delete") {
		$I{dbh}->do("DELETE from content_filters WHERE filter_id = $I{F}{filter_id}");

		titlebar("100%","<B>Deleted filter# $I{F}{filter_id}!</B>","c");
		listFilters();
	}7
}

##################################################################
sub editbuttons {
	my($newarticle) = @_;
	print "\n\n<!-- begin editbuttons -->\n\n";
	print qq[<INPUT TYPE="SUBMIT" NAME="op" VALUE="save"> ] if $newarticle;
	print qq[<INPUT TYPE="SUBMIT" NAME="op" VALUE="preview"> ];
	print qq[<INPUT TYPE="SUBMIT" NAME="op" VALUE="update"> ],
		qq[<INPUT TYPE="SUBMIT" NAME="op" VALUE="delete">] unless $newarticle;
	print "\n\n<!-- end editbuttons -->\n\n";
}

##################################################################
sub saveExtras {
	return unless sqlTableExists($I{F}{section});
	my @extras = sqlSelectColumns($I{F}{section});
	my $E;

	foreach (@extras) { $E->{$_} = $I{F}{$_} }

	if (sqlUpdate($I{F}{section}, $E, "sid='$I{F}{sid}'") eq '0E0') {
		sqlInsert($I{F}{section}, $E);
	}
}

##################################################################
sub updateStory {
	# Some users can only post to a fixed section
	if ($I{U}{asection}) {
		$I{F}{section} = $I{U}{asection};
		$I{F}{displaystatus} = 1;
	}

	$I{F}{writestatus} = 1;

	$I{F}{dept} =~ s/ /-/g;

	($I{F}{aid}) = sqlSelect('aid','stories','sid=' . $I{dbh}->quote($I{F}{sid}))
		unless $I{F}{aid};
	$I{F}{relatedtext} = getRelated("$I{F}{title} $I{F}{bodytext} $I{F}{introtext}")
		. otherLinks($I{F}{aid}, $I{F}{tid});

	sqlUpdate('discussions',{
			sid	=> $I{F}{sid},
			title	=> $I{F}{title},
			url	=> "$I{rootdir}/article.pl?sid=$I{F}{sid}"
		},
		-ts	=> $I{F}{'time'},
		'sid = ' . $I{dbh}->quote($I{F}{sid})
	);

	sqlUpdate('stories', {
			aid		=> $I{F}{aid},
			tid		=> $I{F}{tid},
			dept		=> $I{F}{dept},
			'time'		=> $I{F}{'time'},
			title		=> $I{F}{title},
			section		=> $I{F}{section},
			bodytext	=> $I{F}{bodytext},
			introtext	=> $I{F}{introtext},
			writestatus	=> $I{F}{writestatus},
			relatedtext	=> $I{F}{relatedtext},
			displaystatus	=> $I{F}{displaystatus},
			commentstatus	=> $I{F}{commentstatus}
		}, 'sid=' . $I{dbh}->quote($I{F}{sid})
	);

	$I{dbh}->do('UPDATE stories SET time=now() WHERE sid='
		. $I{dbh}->quote($I{F}{sid})
	) if $I{F}{fastforward} eq 'on';

	saveExtras();
	titlebar('100%', "Article $I{F}{sid} Saved", 'c');
	listStories();
}

##################################################################
sub saveStory {
	$I{F}{sid} = getsid();
	$I{F}{displaystatus} ||= '1' if $I{U}{asection};
	$I{F}{section} = $I{U}{asection} if $I{U}{asection};
	$I{F}{dept} =~ s/ /-/g;
	$I{F}{relatedtext} = getRelated(
		"$I{F}{title} $I{F}{bodytext} $I{F}{introtext}"
	) . otherLinks($I{U}{aid}, $I{F}{tid});

	sqlInsert('storiestuff', { sid => $I{F}{sid} });
	sqlInsert('discussions', {
		sid	=> $I{F}{sid},
		title	=> $I{F}{title},
		ts	=> $I{F}{'time'},
		url	=> "$I{rootdir}/article.pl?sid=$I{F}{sid}"
	});

	$I{F}{writestatus} = 1 unless $I{F}{writestatus} == 10;

	# If this came from a submission, update submission and grant
	# Karma to the user
	if ($I{F}{subid}) {
		my($suid) = sqlSelect(
			'uid','submissions',
			'subid=' . $I{dbh}->quote($I{F}{subid})
		);

		print "Assigning 3 karma to UID $suid" if $suid > 0;

		sqlUpdate('users_info',
			{ -karma => 'karma + 3' }, 
			"uid=$suid"
		) if $suid > 0;

		sqlUpdate('submissions',
			{ del=>2 }, 
			'subid=' . $I{dbh}->quote($I{F}{subid})
		);
	}

	sqlInsert('stories',{
		sid		=> $I{F}{sid},
		aid		=> $I{F}{aid},
		tid		=> $I{F}{tid},
		dept		=> $I{F}{dept},
		'time'		=> $I{F}{'time'},
		title		=> $I{F}{title},
		section		=> $I{F}{section},
		bodytext	=> $I{F}{bodytext},
		introtext	=> $I{F}{introtext},
		writestatus	=> $I{F}{writestatus},
		relatedtext	=> $I{F}{relatedtext},
		displaystatus	=> $I{F}{displaystatus},
		commentstatus	=> $I{F}{commentstatus}
	});

	titlebar('100%', "Inserted $I{F}{sid} $I{F}{title}");
	saveExtras();
	listStories();
}

##################################################################
sub prog2file {
	my($c, $f) = @_;

	my $d = `$c`;
	print "<BR><BR>c is $c<BR>d is $d<BR>\n";
	if (length($d) > 0) {
		open F, ">$f" or die "Can't open $f: $!";
		print F $d;
		close F;
		print "wrote $f<BR>\n";
		return "1";

	} else {
		return "0";
	}
}


main();
$I{dbh}->disconnect if $I{dbh};
1;
