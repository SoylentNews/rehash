update blocks set block = '<!-- begin titlebar block -->

        <TABLE WIDTH="$width" BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR VALIGN="TOP">
                <TD BGCOLOR="$I{bg}[3]"><IMG SRC="$I{imagedir}/cl.gif" WIDTH="7" HEIGHT="10" ALT=""><IMG SRC="$I{imagedir}/pix.gif" WIDTH="4" HEIGHT="4" ALT=""></TD>
                <TD BGCOLOR="$I{bg}[3]" WIDTH="100%">
                        <TABLE WIDTH="100%" BORDER="0" CELLPADDING="2" CELLSPACING="0"><TR>
                                <TD BGCOLOR="$I{bg}[3]"><FONT FACE="$I{mainfontface}" SIZE="${\\( $I{fontbase} + 3 )}" COLOR="$I{fg}[0]"><B>$title</B></FONT></TD>
                        </TR></TABLE>
                </TD>
                <TD BGCOLOR="$I{bg}[3]" ALIGN="right"><IMG SRC="$I{imagedir}/cr.gif" WIDTH="7" HEIGHT="10" ALT=""></TD>
        </TR></TABLE>

<!-- end titlebar block -->
',
blockbak = '<!-- begin titlebar block -->

        <TABLE WIDTH="$width" BORDER="0" CELLPADDING="0" CELLSPACING="0"><TR VALIGN="TOP">
                <TD BGCOLOR="$I{bg}[3]"><IMG SRC="$I{imagedir}/cl.gif" WIDTH="7" HEIGHT="10" ALT=""><IMG SRC="$I{imagedir}/pix.gif" WIDTH="4" HEIGHT="4" ALT=""></TD>
                <TD BGCOLOR="$I{bg}[3]" WIDTH="100%">
                        <TABLE WIDTH="100%" BORDER="0" CELLPADDING="2" CELLSPACING="0"><TR>
                                <TD BGCOLOR="$I{bg}[3]"><FONT FACE="$I{mainfontface}" SIZE="${\\( $I{fontbase} + 3 )}" COLOR="$I{fg}[0]"><B>$title</B></FONT></TD>
                        </TR></TABLE>
                </TD>
                <TD BGCOLOR="$I{bg}[3]" ALIGN="right"><IMG SRC="$I{imagedir}/cr.gif" WIDTH="7" HEIGHT="10" ALT=""></TD>
        </TR></TABLE>

<!-- end titlebar block -->
'
where bid = 'titlebar';

update blocks set block = '<!-- begin fancy box -->

        <TABLE WIDTH="200" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <TR VALIGN="TOP" BGCOLOR="$I{bg}[3]">
                        <TD BGCOLOR="$I{bg}[2]"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                        <TD><IMG SRC="$I{imagedir}/cl.gif" WIDTH="7" HEIGHT="10" ALT=""></TD>
                        <TD><FONT FACE="$I{mainfontface}" SIZE="${\\( $I{fontbase} + 1 )}" COLOR="$I{fg}[0]"><B>$title</B></FONT></TD>
                        <TD ALIGN="RIGHT"><IMG SRC="$I{imagedir}/cr.gif" WIDTH="7" HEIGHT="10" ALT=""></TD>
                        <TD BGCOLOR="$I{bg}[2]" ALIGN="RIGHT"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                </TR>
        </TABLE>

        <TABLE WIDTH="200" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <TR><TD BGCOLOR="$I{bg}[3]" COLSPAN="3"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="1" HEIGHT="1"></TD></TR>
                <TR>
                        <TD BACKGROUND="$I{imagedir}/sl.gif"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                        <TD BGCOLOR="$I{bg}[1]" WIDTH="100%"><TABLE WIDTH="100%" BORDER="0" CELLPADDING="5" CELLSPACING="0"><TR><TD BGCOLOR="$I{bg}[1]">
                                <FONT FACE="$I{mainfontface}" SIZE="${\\( $I{fontbase} + 1 )}">

$contents

</FONT>
                        </TD></TR></TABLE></TD>
                        <TD BACKGROUND="$I{imagedir}/sr.gif" ALIGN="right"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                </TR>
                <TR BGCOLOR="$I{bg}[3]"><TD COLSPAN="3"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="1" HEIGHT="1"></TD></TR>
        </TABLE>
<P>


<!-- end fancy box -->
',
blockbak = '<!-- begin fancy box -->

        <TABLE WIDTH="200" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <TR VALIGN="TOP" BGCOLOR="$I{bg}[3]">
                        <TD BGCOLOR="$I{bg}[2]"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                        <TD><IMG SRC="$I{imagedir}/cl.gif" WIDTH="7" HEIGHT="10" ALT=""></TD>
                        <TD><FONT FACE="$I{mainfontface}" SIZE="${\\( $I{fontbase} + 1 )}" COLOR="$I{fg}[0]"><B>$title</B></FONT></TD>
                        <TD ALIGN="RIGHT"><IMG SRC="$I{imagedir}/cr.gif" WIDTH="7" HEIGHT="10" ALT=""></TD>
                        <TD BGCOLOR="$I{bg}[2]" ALIGN="RIGHT"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                </TR>
        </TABLE>

        <TABLE WIDTH="200" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <TR><TD BGCOLOR="$I{bg}[3]" COLSPAN="3"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="1" HEIGHT="1"></TD></TR>
                <TR>
                        <TD BACKGROUND="$I{imagedir}/sl.gif"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                        <TD BGCOLOR="$I{bg}[1]" WIDTH="100%"><TABLE WIDTH="100%" BORDER="0" CELLPADDING="5" CELLSPACING="0"><TR><TD BGCOLOR="$I{bg}[1]">
                                <FONT FACE="$I{mainfontface}" SIZE="${\\( $I{fontbase} + 1 )}">

$contents

</FONT>
                        </TD></TR></TABLE></TD>
                        <TD BACKGROUND="$I{imagedir}/sr.gif" ALIGN="right"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="3" HEIGHT="3" ALT=""></TD>
                </TR>
                <TR BGCOLOR="$I{bg}[3]"><TD COLSPAN="3"><IMG SRC="$I{imagedir}/pix.gif" WIDTH="1" HEIGHT="1"></TD></TR>
        </TABLE>
<P>


<!-- end fancy box -->
'
where bid = 'fancybox';





