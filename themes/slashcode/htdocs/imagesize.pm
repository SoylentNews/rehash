package imagesize;

# all this image code was directly ripped off from
# Alex Knowles, alex@ed.ac.uk
# based on original code and idea by Andrew Tong,  werdna@ugcs.caltech.edu
# taken from his wwwis program: http://www.tardis.ed.ac.uk/~ark/wwwis/
# Much Thanks to them.
#
# imagesize: returns x,y dimensions of a jpg or gif.  eg,
# my ($h,$w)=imagesize("/tmp/foo.gif");

sub imagesize {
  my($file)=@_;
  my($x,$y)=(0,0);
  
  if( defined($file) && open(STRM, "<$file") ){
    $_=$file;
    if (/\.jpg$/i || /\.jpeg$/i) {
      ($x,$y) = &jpegsize(\*STRM);
    } elsif(/\.gif$/i) {
      ($x,$y) = &gifsize(\*STRM);
    } else {
      print "$file is naughty";
    }
    close(STRM);
  }  
  return ($x,$y);
}

# part of NEWgifsize
sub gif_blockskip {
  my ($GIF, $skip, $type) = @_;
  my ($s)=0;
  my ($dummy)='';
  
  read ($GIF, $dummy, $skip);	# Skip header (if any)
  while (1) {
    if (eof ($GIF)) {
      warn "Invalid/Corrupted GIF (at EOF in GIF $type)\n";
      return "";
    }
    read($GIF, $s, 1);		# Block size
    last if ord($s) == 0;	# Block terminator
    read ($GIF, $dummy, ord($s));	# Skip data    
  }
}

# this code by "Daniel V. Klein" <dvk@lonewolf.com>
sub gifsize {
  my($GIF) = @_;
  my($cmapsize, $a, $b, $c, $d, $e)=0;
  my($type,$s)=(0,0);
  my($x,$y)=(0,0);
  my($dummy)='';
  
  return($x,$y) if(!defined $GIF);
  
  read($GIF, $type, 6); 
  if($type !~ /GIF8[7,9]a/ || read($GIF, $s, 7) != 7 ){
    warn "Invalid/Corrupted GIF (bad header)\n"; 
    return($x,$y);
  }
  ($e)=unpack("x4 C",$s);
  if ($e & 0x80) {
    $cmapsize = 3 * 2**(($e & 0x07) + 1);
    if (!read($GIF, $dummy, $cmapsize)) {
      warn "Invalid/Corrupted GIF (global color map too small?)\n";
      return($x,$y);
    }
  }
 FINDIMAGE:
  while (1) {
    if (eof ($GIF)) {
      warn "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)\n";
      return($x,$y);
    }
    read($GIF, $s, 1);
    ($e) = unpack("C", $s);
    if ($e == 0x2c) {		# Image Descriptor (GIF87a, GIF89a 20.c.i)
      if (read($GIF, $s, 8) != 8) {
	warn "Invalid/Corrupted GIF (missing image header?)\n";
	return($x,$y);
      }
      ($a,$b,$c,$d)=unpack("x4 C4",$s);
      $x=$b<<8|$a;
      $y=$d<<8|$c;
      return($x,$y);
    }
    if ($type eq "GIF89a") {
      if ($e == 0x21) {		# Extension Introducer (GIF89a 23.c.i)
	read($GIF, $s, 1);
	($e) = unpack("C", $s);
	if ($e == 0xF9) {	# Graphic Control Extension (GIF89a 23.c.ii)
	  read($GIF, $dummy, 6);	# Skip it
	  next FINDIMAGE;	# Look again for Image Descriptor
	} elsif ($e == 0xFE) {	# Comment Extension (GIF89a 24.c.ii)
	  &gif_blockskip ($GIF, 0, "Comment");
	  next FINDIMAGE;	# Look again for Image Descriptor
	} elsif ($e == 0x01) {	# Plain Text Label (GIF89a 25.c.ii)
	  &gif_blockskip ($GIF, 12, "text data");
	  next FINDIMAGE;	# Look again for Image Descriptor
	} elsif ($e == 0xFF) {	# Application Extension Label (GIF89a 26.c.ii)
	  &gif_blockskip ($GIF, 11, "application data");
	  next FINDIMAGE;	# Look again for Image Descriptor
	} else {
	  printf STDERR "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
	  return($x,$y);
	}
      }
      else {
	printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n", $e;
	return($x,$y);
      }
    }
    else {
      warn "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
      return($x,$y);
    }
  }
}


# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
sub jpegsize {
  my($JPEG) = @_;
  my($done)=0;
  my($c1,$c2,$ch,$s,$length, $dummy)=(0,0,0,0,0,0);
  my($a,$b,$c,$d);
  
  if(defined($JPEG)		&&
     read($JPEG, $c1, 1)	&&
     read($JPEG, $c2, 1)	&&
     ord($c1) == 0xFF		&& 
     ord($c2) == 0xD8		){
    while (ord($ch) != 0xDA && !$done) {
      # Find next marker (JPEG markers begin with 0xFF)
      # This can hang the program!!
      while (ord($ch) != 0xFF) { return(0,0) unless read($JPEG, $ch, 1); }
      # JPEG markers can be padded with unlimited 0xFF's
      while (ord($ch) == 0xFF) { return(0,0) unless read($JPEG, $ch, 1); }
      # Now, $ch contains the value of the marker.
      if ((ord($ch) >= 0xC0) && (ord($ch) <= 0xC3)) {
	return(0,0) unless read ($JPEG, $dummy, 3); 
	return(0,0) unless read($JPEG, $s, 4);
	($a,$b,$c,$d)=unpack("C"x4,$s);
	return ($c<<8|$d, $a<<8|$b );
      } else {
	# We **MUST** skip variables, since FF's within variable names are
	# NOT valid JPEG markers
	return(0,0) unless read ($JPEG, $s, 2); 
	($c1, $c2) = unpack("C"x2,$s); 
	$length = $c1<<8|$c2;
	last if (!defined($length) || $length < 2);
	read($JPEG, $dummy, $length-2);
      }
    }
  }
  return (0,0);
}

1;
