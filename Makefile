# $Id$

all:
	@echo "There is nothing to compile here, just type 'make (de)install'"

install:
	install -o root -g wheel -m 0555 cdeploy.sh /usr/local/sbin/cdeploy

deinstall:
	rm -f /usr/local/sbin/cdeploy
