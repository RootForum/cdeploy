# $Id$

all:
	cp cdeploy.sh cdeploy
	chmod 0555 cdeploy

install:
	install -o root -g wheel -m 0555 cdeploy.sh /usr/local/sbin/cdeploy
	install -o root -g wheel -m 0444 cdeploy.1 /usr/local/man/man1/cdeploy.1
	gzip -f9 /usr/local/man/man1/cdeploy.1

deinstall:
	rm -f /usr/local/sbin/cdeploy
	rm -f /usr/local/man/man1/cdeploy.1.gz
