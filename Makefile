# $Id$

all:
	@echo "There is nothing to compile here, just type 'make (de)install'"

install:
	install -o root -g wheel -m 0555 config-deploy.sh /usr/local/sbin/config-deploy

deinstall:
	rm -f /usr/local/sbin/config-deploy
