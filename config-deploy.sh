#!/bin/sh

## 
# @file deploy.sh
# @brief deploy configuration files into the system
#
# @copyright
# ====================================================================
#
# Copyright (c) 2009
#     Jesco Freund <aihal@users.sourceforge.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# ====================================================================
# @endcopyright
#
# @version $Id$
##

b_awk="/usr/bin/awk"
b_basename="/usr/bin/basename"
b_cap="/usr/bin/cap_mkdb"
b_cut="/usr/bin/cut"
b_date="/bin/date"
b_dirname="/usr/bin/dirname"
b_find="/usr/bin/find"
b_grep="/usr/bin/grep"
b_head="/usr/bin/head"
b_id="/usr/bin/id"
b_install="/usr/bin/install"
b_mkdir="/bin/mkdir"
b_stat="/usr/bin/stat"

red="\033[1;31m"
green="\033[1;32m"
normal="\033[0m"

db_list=""
runuser=$($b_id -un)
wrkdir=$($b_grep $runuser /etc/passwd | $b_head -1 | $b_awk -F: '{print $6}')

# create working directory
if [ ! -d "${wrkdir}/config" ]
then
	echo -n "$wrkdir/config does not exist. trying to create it... "
	{ $b_mkdir ${wrkdir}/config; } > /dev/null 2>/dev/null
	if [ "$?" -ne "0" ]
	then
		echo -e "${red}failed${normal}"
		exit 1
	else
		echo -e "${green}success${normal}"
	fi
fi

# create backup location
location=$($b_date "+${wrkdir}/config/%Y%m%d-%H%M%S")
echo -n "creating backup directory in ${location} ... "
{ $b_mkdir $location; } >/dev/null 2>/dev/null
if [ "$?" -ne "0" ]
then
	echo -e "${red}failed${normal}"
	exit 1
else
	echo -e "${green}success${normal}"
fi


for i in $($b_find . -type f | $b_grep -v 'deploy\.sh')
do
	orig=$(echo $i | sed 's/^\.//')
	odir=$($b_dirname $orig)
	echo -n "deploying $($b_basename $i) to ${orig} ... "

	# is this file a template for a db file?
	if [ -f "${orig}.db" ]
	then
		if [ -z "${db_list}" ]
		then
			db_list=$orig
		else
			db_list="${db_list} ${orig}"
		fi
	fi

	# determine mode of original file
	if [ -f "$orig" ]
	then
		user=$($b_stat -f "%Su" $orig)
		group=$($b_stat -f "%Sg" $orig)
		mode=$($b_stat -f "%p" $orig | $b_cut -c 3-6)
	else
		user=$($b_id -urn)
		group=$($b_id -grn)
		mode=$($b_stat -f "%p" $i | $b_cut -c 3-6)
	fi

	# create backup of original file (if it exists)
	if [ -f "$orig" ]
	then
		{ $b_mkdir -p ${location}$($b_dirname ${orig}); } >/dev/null 2>/dev/null
		{ $b_install -S -o $user -g $group -m $mode $orig ${location}${odir}; } >/dev/null 2>/dev/null
		if [ "$?" -ne "0" ]
		then 
			echo -e "${red}failed${normal}"
			continue
		fi
	fi

	# deploy new file
	if [ ! -d $($b_dirname $orig) ]
	then
		{ $b_mkdir -p $($b_dirname $orig); } >/dev/null 2>/dev/null
	fi
	{ $b_install -S -o $user -g $group -m $mode $i $orig; } >/dev/null 2>/dev/null
	if [ "$?" -ne "0" ]
	then
		echo -e "${red}failed${normal}"
	else
		echo -e "${green}success${normal}"
	fi
done

# re-create .db files if necessary...
for i in $db_list
do
	echo -n "refreshing db file for $i ... "
	{ $b_cap $i; } >/dev/null 2>/dev/null
	if [ "$?" -ne "0" ]
	then
		echo -e "${red}failed${normal}"
	else
		echo -e "${green}success${normal}"
	fi
done

exit 0	
