#!/usr/bin/perl -w

###############################################################################
# pdaGen - based on dailyStuff, gets the headlines and spits out 
# a simple page that's viewable by palm
# This is not the final direction I wish to go with
# wireless devices, but it at least is a small engine
# to generate palm viewable pages until the main codebase
# has all of its presentation out of the code
#
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# pdaGen written 6/2000 by Patrick "CaptTofu" Galbraith
# patrick.galbraith@andover.net
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

=head1 NAME

pdaGen.pl

=head1 SYNOPSIS

	$HOME/contrib/pdaGen.pl

=head1 DESCRIPTION

pdaGen.pl is a simple script that get 3 days worth of stories, and the top
ten comments for each story, and then prints out various pages that are
formatted to be suitable for the palm (clipping apps in particular), each page
not exceding 1000 bytes.

This isn't the framework for how I want to do things in the future for slashcode
and portables. I would really like to make it so that slashcode can print out
whatever format a site operator would like to use.

This script is unfinished and may not even work properly.  It gets the last
three days of stories, which may not be right for your site.  But if you
are up to it, you can play with this.

=over

=head2 PREREQUISITES

Get all the images (particularly the topics) and convert them (you can use mogrify)
to 45x45 size, and put them in F<$HOME/public_html/images/palm>
(with the same directory structure as F<$HOME/public_html/images>).

=cut

use lib '..';
use strict;
use vars '%I';
use File::Path;
use Slash;
use Date::Manip qw(DateCalc UnixDate);

*I = getSlashConf();
$I{pda_url} = "/palm";
$I{pda_mainpage} = $I{pda_url} . "/headlines_1.shtml";
$I{pda_oldmainpage} = $I{pda_url} . "/older_headlines_1.shtml";
# this is when this was first run

mkpath "$I{basedir}$I{pda_url}", 0, 0755;
symlink "$I{basedir}$I{pda_mainpage}", "$I{basedir}$I{pda_url}/index.html";
symlink "$I{basedir}$I{pda_mainpage}", "$I{basedir}$I{pda_url}/index.shtml";

=pod

$I{pda_startdate} is the day that you first run this script. 
This isn't how I want to do things, but it works for now.

=cut

$I{pda_startdate} = "2000-07-28 22:00:00";

##############################################################
sub makeDir {
	my($section, $sid) = @_;

        my $monthid = substr($sid, 3, 2);
        my $yearid = substr($sid, 0, 2);
        my $dayid = substr($sid, 6, 2);

        mkpath "$I{basedir}/$I{pda_url}/$section/$yearid/$monthid/$dayid", 0, 0755;
}

##############################################################
sub palmHeader {
	my $title = shift;

	my $header = qq|<html><head><title>$title</title><meta name="palmcomputingplatform" content="true"><meta name="palmlauncherrevision" content="1.0"></head>|;

	return($header);
}

##############################################################
sub pageHeader {
	my $title = shift;
	my $imageflag= shift;
	my $sitegif_url = qq|<a href="$I{pda_mainpage}"><img src="$I{imagedir}/palm/title_palm.gif"></a>&nbsp;&nbsp;| if $imageflag;
	my $page_header = qq|<body><center>$sitegif_url<p><b>$title</b></p></center>|;

	return($page_header);
}

##############################################################

=pod

=head2 SUBROUTINES

sub cleanContent : makes sure there's nothing that we want to 
throw off palm viewing

=cut

sub cleanContent {
		# by reference
		my $content = shift;

		$$content =~ s/<br$/<br>/i;
		$$content =~ s/<p$/<p>/i;
		$$content =~ s/<\/p$/<\/p>/i;
		$$content =~ s/\n|\r/ /gi;
		$$content =~ s/\t/&nbsp;&nbsp;&nbsp;/gi;
		$$content =~ s/<p>/<br><br>/gi;
		$$content =~ s/<\/p>/<br>/gi;
		$$content =~ s/<table.*>/<p>/gi;
		$$content =~ s/<\/table>/<\/p>/gi;
		$$content =~ s/<tr.*>/ /gi;
		$$content =~ s/<\/tr>/<br>/gi;
		$$content =~ s/<td.*>/ /gi;
		$$content =~ s/<\/td>/&nbsp;&nbsp;&nbsp;/gi;
}

##############################################################

=pod

sub getContent : gets all the data into one big 
data structure for later processing

=cut

sub getContent {

	my $stories = shift;
	# my $columns = "sid,introtext,bodytext,title,section,aid,tid,date_format(time,\"\%W \%M \%d, \@h:\%i\%p\"),dept";
	my $columns = "sid,introtext,bodytext,title,section,aid,tid,time,dept";
	my $tables = "newstories";
	my $where = "displaystatus=0 AND to_days(time) > to_days(now()) -3 AND time < now()";
	my $other = "ORDER BY time DESC";
	my $comment_limit = 10;
	my $story_select = sqlSelectAll($columns,$tables,$where,$other) or die DBI::errstr;
	my $i = 0;

	for (@{$story_select}) {
		my($sid, $introtext,$bodytext,$title, $section, $aid, $tid, $time, $dept) = @$_;
		my $story = $introtext . $bodytext;

		cleanContent(\$story);
		
		$stories->[$i] = { 
			sid => $sid,
			title => $title,
			# puts ~1000 char chunks, broken on words into an array
			story => [ $story =~ /(.{1,1000}\b\.?\)?)/gs ],
			section => $section,
			aid => $aid,
			tid => $tid,
			time => $time,
			dept => $dept };

		my $columns = "date,cid,pid,uid,subject,comment,points,reason";
		my $tables = "comments";
		my $where = "sid = '$sid'";
		my $other = "ORDER BY points DESC limit $comment_limit";

		my $comment_select = sqlSelectAll($columns,$tables,$where,$other) or die DBI::errstr;

		$stories->[$i]->{comments} = [@{$comment_select}];

		$i++;
	}
}

##############################################################

=pod

sub printMainPage : prints the main
page, 1000 bytes for each page; prints out enough pages to
print all the stories in the data structure

=cut

sub printMainPage {
	my $stories = shift;

	my $debug = 0;
	my $pagenum = 1;
	my $header = palmHeader("$I{sitename} $I{slogan}");
	$header .= pageHeader("$I{sitename}: $I{slogan}",1);
	my $footer = qq|</body></html>|;

	my $page = $header;

	my $url = $I{pda_mainpage}; 
	my $filename = $I{datadir} . "/public_html" . $url; 
	my $nav = qq|<a href="$I{pda_mainpage}"><font size="-1">Home page</a><br>|;
	$nav .= qq|<br><a href="$I{pda_oldmainpage}">Older Stuff</a>|;

	# DEBUG
	print "opening $filename\n" if $debug;
	open(HEADLINES,">$filename") or die "unable to open file headlines $filename $!\n";

	my $storynum = 0;

	for( @{$stories}) {
		my ($sid,$title, $section,$aid,$tid,$time,$dept) = ( 
		$_->{sid},
		$_->{title},
		$_->{section},
		$_->{aid},
		$_->{tid},
		$_->{time},
		$_->{dept} );
		
		my $nextprev_link = "";
		my $back = "$I{pda_url}/headlines_" . ($pagenum - 1) . ".shtml";

		print "title $title sid $sid time $time $storynum\n" if $debug;
		$page .= qq|<a href="$I{pda_url}/$section/| . $sid . qq|_1.shtml">$title</a><br>|;
		
		if (length($page) > 1000 && $storynum < (@{$stories} - 1)) {
			$url = "$I{pda_url}/headlines_" . ($pagenum + 1) . ".shtml";
			$filename = $I{datadir} . "/public_html" . $url;

			if ($pagenum > 1) {
				$page .= qq|<br><font size="-1"><a href="$back">&lt;-- Previous page (page | . ($pagenum -1) . qq| )</a></font>|;
			}
			$page .= qq|<br><font size="-1"><a href="$url">Stories continued (page | . ($pagenum + 1) . qq| ) --&gt;</a></font><br>|;
			$page .= $nav;
			$page .= $footer;

			print HEADLINES $page;
			close(HEADLINES);
			# DEBUG
#			print "opening $filename\n";
			open(HEADLINES,">$filename") or die "unable to open headlines file $filename $!\n";

			$pagenum++;

			if ($pagenum > 1) {
				$header = palmHeader("$I{sitename} $I{slogan}");
				$header .= pageHeader("$I{sitename}: $I{slogan} (page $pagenum)",1);
			}

			$page = $header;
		} 
		elsif ($storynum == (@{$stories} - 1)) {
			if ($pagenum > 1) {
				my $back = "$I{pda_url}/headlines_" . ($pagenum - 1) . ".shtml";
				$page .= qq|<br><font size="-1"><a href="$back">&lt;-- Previous page</a></font><br>|;
			}
			$page .= $nav;
			$page .= $footer;
			print HEADLINES $page;
			close(HEADLINES);
		}

		if ($storynum > 0) {
			my $prevsid = $stories->[$storynum - 1]->{sid} ; 
			$nextprev_link .= qq|&lt;-- <a href="$I{pda_url}/$stories->[$storynum -1]->{section}/$prevsid| . qq|_1.shtml">| . "$stories->[$storynum -1]->{title}</a><br>";
		} else {
			$nextprev_link .= "<br>";
		}
		
		if ($storynum < (@{$stories}) - 1) {
			my $nextsid = $stories->[$storynum + 1]->{sid} ;
			$nextprev_link .= qq|<a href="$I{pda_url}/$stories->[$storynum +1]->{section}/$nextsid| . qq|_1.shtml">| . "$stories->[$storynum +1]->{title}</a> --&gt;";
		}
			
		$_->{nextprev} = $nextprev_link;
	
		$storynum ++;
	}
}

##############################################################

=pod

sub printOlderIndex : gets all the story sids prior
to the last three days, but after three days before pda stories were 
created on the system; this way, it only needs to link to pages
that have already been created

=cut

sub printOlderIndex {

	# ok, say what you want.
	my $debug = 0;
	my $header = palmHeader("$I{sitename} $I{slogan}");
	$header .= pageHeader("$I{sitename}: $I{slogan}, older stuff",1);
	my $footer = qq|</body></html>|;

	my $from = &UnixDate(&DateCalc($I{pda_startdate},"- 3 days"),"%Y-%m-%d %T");
	my $to = &UnixDate(&DateCalc("today","- 2 days"),"%Y-%m-%d %T");
	my $page = "";
	my $pagenum = 1;
	my $i = 0;
	
	my $table = "stories";
	my $columns = "section,sid,title";
	my $where = "displaystatus=0 AND time > '$from' AND time < '$to'";
	my $other = "ORDER BY time DESC";

	my $oldsid_arrayref = sqlSelectAll($columns,$table,$where,$other);

	for(@{$oldsid_arrayref}) {
		my ($section,$sid,$title) = @$_;
		print "section $section sid $sid title $title\n" if $debug;
		$page .= qq|<a href="$I{pda_url}/$section/| . $sid . qq|_1.shtml">$title</a><br>|;

		if( length($header . $page . $footer) > 1000 || $i == $#{$oldsid_arrayref}) {
			my $filename = "older_headlines_" . $pagenum . ".shtml";
			my $nextprev = qq|<br><a href="$I{pda_url}/older_headlines_| . ($pagenum - 1) . qq|.shtml">&lt;-- Previous page (page | . ($pagenum - 1) . qq| )</a>| if $pagenum > 1;
			$nextprev .= qq|<br><a href="$I{pda_url}/older_headlines_| . ($pagenum + 1 ) . qq|.shtml">Next page (page | . ($pagenum + 1) . qq| ) --&gt;</a>| if $i < $#{$oldsid_arrayref};

			print "opening $I{datadir}/public_html/$I{pda_url}/$filename\n" if $debug;
			open(COMMENTS,">$I{datadir}/public_html/$I{pda_url}/$filename") or die "unable to open $filename $!\n";
			print COMMENTS $header;
			print COMMENTS $page;
			print COMMENTS $nextprev;
			print COMMENTS qq|<br><a href="$I{pda_oldmainpage}">First Page of Older Stuff</a>| if $pagenum > 1;
			print COMMENTS qq|<br><a href="$I{pda_mainpage}">Home Page</a>|;
			print COMMENTS $footer;
			close(COMMENTS);

			$pagenum++;
			$page ="";
			$nextprev = "";
		} 
		$i++;
	}
}
##############################################################

=pod

sub printArticles : prints out each article
in the stories data structure, and only prints out 1000 bytes
per page, meaning that it will print out continuation pages
if necessary

=cut

sub printArticles {
	my $stories = shift;

	my $debug = 0;

	my $storynum = 0;
	my $footer = "</body></html>";

	my $topic_hashref = {};
	my $topics = sqlSelectAll("tid,image","topics");

	for(@{$topics}) {
		# print "$_->[0] $_->[1]\n";
		$topic_hashref->{$_->[0]} = $_->[1];
	}

	for( @{$stories}) {
		my ($sid,$title, $story, $section,$aid,$tid,$time,$dept,$nextprev_link) = ( 
		$_->{sid},
		$_->{title},
		$_->{story},
		$_->{section},
		$_->{aid},
		$_->{tid},
		$_->{time},
		$_->{dept},
		$_->{nextprev} );

	# print "num stories " . (@{$stories}) . "\n";	
		$topic_hashref->{$tid} =~ /(.*)\.(gif|jpg)/i;
		my $topic_icon = $1 . "_palm." . $2;

		my $header = palmHeader($title);
		my $articlepage_header = pageHeader("$I{sitename}: $I{slogan}</b><hr>",0);

		my $article_header = qq|<p><b>$title</b></p><img align="right" src="$I{imagedir}/palm/topics/$topic_icon"><br><p><font size="-1">from the <i>$dept dept.</i> posted by <b>$aid</b> on $time ($tid)</font><br>|;

		my $page = $header . $articlepage_header . $article_header;

		my $pagenum = 1;
		my $url = "$I{pda_url}/$section/$sid" . "_" . $pagenum . ".shtml";
		my $file = $I{datadir} . "/public_html" . $url;

		my $commentspage_url = "$I{pda_url}/$section/$sid" . "_comments.shtml";
		my $nav = qq|<br><font size="-1">$nextprev_link</font>|;
		$nav .= qq|<br><font size="-1"><a href="$I{pda_mainpage}">Home page</a></font><br>|;
		$nav .= qq|<br><font size="-1"><a href="$commentspage_url">View top 10 comments</a></font><br>|;
		$nav .= qq|<br><a href="$I{pda_oldmainpage}">Older Stuff</a>|;

		makeDir($section,$sid);
		open(ARTICLE,">$file") or die "unable to open article file $file $!\n";
		# DEBUG
		print "opening article_file $file\n" if $debug;

		for(@{$story}) {
			$page .= "<p>" if $_ !~ /<p>/gi; 
			$page .= $_;
			$page .= "</p>" if $_ !~ /<\/p>/gi; 

			if ($pagenum > 1) {
				my $back = "$I{pda_url}/$section/$sid" . "_" . ($pagenum - 1) . ".shtml";
				$page .= qq|<br><font size="-1"><a href="$back">&lt;-- Previous page</a></font><br>|;
			}

			if ( $pagenum < @{$story}) {
				my $url = "$I{pda_url}/$section/$sid" . "_" . ($pagenum + 1) . ".shtml";
				my $back = "$I{pda_url}/$section/$sid" . "_" . ($pagenum) . ".shtml";
				my $file = $I{datadir} . "/public_html" . $url;


				$page .= qq|<br><font size="-1"><a href="$url">Next page --&gt;</a></font><br>|;
				$page .= $nav;
				$page .= $footer;
				print ARTICLE $page;
				close(ARTICLE);

				open(ARTICLE,">$file") or die "unable to open article file $file $!\n";
				# print "opening article_file $file\n";
				$page = $header;
				$page .= qq|<br><a href="$back">... Continued</a><br>|;
			} else {
				$page .= $nav;
				$page .= $footer;
				print ARTICLE $page;
				close(ARTICLE);
			}
			$pagenum++;
		}
		$storynum++;
	}
}

##############################################################

=head2

sub printArticleComments : prints out all the 
comments for each story, 1000 bytes of each
comment, and the pages for each comment 
required to print out all the comments

=cut

sub printArticleComments {
	my $stories = shift;

	my $debug = 0;

	my $storynum = 0;

	my $footer = "</body></html>";
	
	for (@{$stories}) {
		my $commentnum = 1;

		my ($sid,$title, $comments, $section,$nextprev_link,$tid) = ( 
		$_->{sid},
		$_->{title},
		$_->{comments},
		$_->{section},
		$_->{nextprev},
		$_->{tid});
		
		my $article_url = "$I{pda_url}/$section/$sid" . "_1.shtml";
		my $comment_index_file= "$I{datadir}/public_html/$I{pda_url}/$section/" . $sid . "_comments.shtml";
		my $url = "$I{pda_url}/$section/$sid" . "_comments_" . $commentnum . "-1.shtml";
		my $file = $I{datadir} . "/public_html" . $url;

		my $nav = qq|<font size="-1"><a href="$article_url">Story: $title</a><br>|;
		$nav .= qq|$nextprev_link<br><a href="$I{pda_mainpage}">Home Page</a></font>|;	
		$nav .= qq|<br><a href="$I{pda_oldmainpage}">Older Stuff</a>|;

		my $header = palmHeader("Comments: $_->{title}");
		$header .= pageHeader("Comments: $_->{title}",0);
		my $index_page = $header;

			# DEBUG
			print "opening $comment_index_file\n" if $debug;
		open(COMMENT_INDEX,">$comment_index_file") or die "unable to open comment_index_file file $comment_index_file $!\n";
		print COMMENT_INDEX $index_page;
		close(COMMENT_INDEX);

		for(@{$comments}) {
			my ($date,$cid,$pid,$uid,$subject,$comment,$points,$reason) = @{$_};


			open(COMMENT_INDEX,">>$comment_index_file") or die "unable to open comment_index file $comment_index_file $!\n";
			print COMMENT_INDEX qq|<a href="$url">$subject</a><br>|;
			close(COMMENT_INDEX);
			
			my @comment_array = ($comment =~ /(.{1,1000}\b\.?)/gs); 

			# DEBUG
			print "length of comment " . length($comment) . " \n" if $debug;

			my ($nickname,$fakeemail) = sqlSelect("nickname, fakeemail","users","uid = $uid");

			# DEBUG
			print "opening comments $file\n" if $debug;	
			open(COMMENTS,">$file") or die "unable to open comments file $file $!\n";

			my $page = $header;
			my $comment_arraynum = 0;

			for(@comment_array) {	
				my $comments_back = $url;
				cleanContent(\$_);

				if ($comment_arraynum < $#comment_array) {
					my $back = $url;

					$url = "$I{pda_url}/$section/" . $sid . "_comments_" . $commentnum . "-" . ($comment_arraynum + 2) . ".shtml";

					$file = "$I{datadir}/public_html" . $url;

					$page .= "<font size=\"-1\"><b>$subject</b> (Score: $points, $I{reasons}[$reason])<br>by $nickname ";
					$page .= qq|<a mailto="$fakeemail">($fakeemail)</a>| if $fakeemail ne '';
					$page .= "(Page " . ($comment_arraynum + 1) . " of ";
					$page .= @comment_array . " pages of comment $commentnum of "; 
					$page .= @{$comments} . " comments<br>)</font>";
		
					$page .= "<p>" if $_ !~ /<p>/gi; 
					$page .= $_;
					$page .= "</p>" if $_ !~ /<\/p>/gi; 
					$page .= qq|<br><font size="-1"><a href="$url">Next page --&gt;</a></font><br>|;
					$page .= qq|<br><font size="-1"><a href="$back">&lt;-- Previous page</a></font><br>| if $comment_arraynum > 0;
					$page .= qq|<br><font size="-1"><a href="$I{pda_url}/$section/$sid| . "_comments_" . ($commentnum + 1) . qq|-1.shtml">Next comment --&gt;</a><br></font>| if ($commentnum < @{$comments}); 

					$page .= qq|<br><font size="-1"><a href="$I{pda_url}/$section/$sid| . "_comments_" . ($commentnum - 1) . qq|-1.shtml">&lt;-- Previous comment</a></font><br>| if $commentnum > 1;
					$page .= $nav; 
					$page .= $footer;

					print COMMENTS $page;
					close(COMMENTS);

					open(COMMENTS,">$file") or die "unable to open comments file $file $!\n";
					
					# DEBUG
					print "opening $file\n" if $debug;

					$page = $header;
					$page .= qq|<font size="-1">Continued from <a href="$I{pda_url}/$section/$sid| . "_comments_" . $commentnum . "-" . ($comment_arraynum + 1) . qq|.shtml">Previous page</a></font><br>|;

				} else { # otherwise, last element, or zero elements
					my ($prev_comment,$prev_page) = ("","");
					my $back = $url;

					$url = "$I{pda_url}/$section/$sid" . "_comments_" . ($commentnum + 1) . "-1.shtml";
					$file = "$I{datadir}/public_html" . $url;

					if( $commentnum > 1) {
						$prev_comment = qq|<font size="-1"><a href="$I{pda_url}/$section/$sid| . "_comments_" . ($commentnum - 1) . qq|-1.shtml">&lt;-- Previous Comment</a></font><br>|;
					} 	

					if ($comment_arraynum > 0 ) {
						$prev_page = qq|<font size="-1"><a href="$I{pda_url}/$section/$sid| . "_comments_" . $commentnum . "-" . $comment_arraynum . qq|.shtml">&lt;-- Previous page</a></font><br>|;
		
					} 
				
					$page .= qq|<font size="-1"><b>$subject</b> (Score: $points, $I{reasons}[$reason])<br>by $nickname |;
					$page .= qq|<a mailto="$fakeemail">($fakeemail)</a>| if $fakeemail ne '';
					if(@comment_array > 1) {
						$page .= "(Page " . ($comment_arraynum + 1) . " of " . @comment_array . " pages of comment " . $commentnum . " of " . @{$comments} . " comments)<br>";
					} else {
						$page .= "(Comment " . $commentnum . " of " . @{$comments} . " comments)<br>";
					}
					$page .= "</font><p>$_</p>";
					$page .= $prev_comment . $prev_page; 
					$page .= qq|<br><font size="-1"><a href="$url">Next comment --&gt;</a></font><br>| if $commentnum < @{$comments};
					$page .= $nav; 
					$page .= $footer; 

					print COMMENTS $page;
					close(COMMENTS);
				}
				$comment_arraynum++;
			}
			$commentnum++;
		}

		$storynum++;

		open(COMMENT_INDEX,">>$comment_index_file") or die "unable to open comment_index file $comment_index_file $!\n";
		print COMMENT_INDEX "<br>$nav";
		print COMMENT_INDEX $footer;
		close(COMMENT_INDEX);
	}
}

##############################################################
sub main {

	my $stories = [];

	getContent($stories);	

	printMainPage($stories);

	printArticles($stories);

	printArticleComments($stories);

	printOlderIndex();

}

main();
exit(0);
