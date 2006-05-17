# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

##
##  Makefile -- Tagboxes Makefile, implements only one target: clean.
##
TAGBOXES=`find . -maxdepth 1 -name CVS -prune -o -type d -print | sed 's/^\\.$$//'`

all: clean

clean:
	for a in $(TAGBOXES); do \
		(cd $$a; if [ -f Makefile ]; then make clean; fi) \
	done
