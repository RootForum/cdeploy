#!/bin/sh

# Configuration File Deployment Tool
# deploys configuration files into the system
#
# Copyright (c) 2009 Jesco Freund <aihal@users.sourceforge.net>
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
# $Id$
#


detect_binary() {

	local BINDIRS="/bin /usr/bin /sbin /usr/sbin /usr/local/bin /usr/local/sbin"
	local rval=""

	for i in $BINDIRS
	do
		if [ -x "${i}/${1}" ]
		then
			rval="${i}/${1}"
			break
		fi
	done

	echo $rval
}


b_awk=$(detect_binary "awk")
b_basename=$(detect_binary "basename")
b_cap=$(detect_binary "cap_mkdb")
b_cut=$(detect_binary "cut")
b_date=$(detect_binary "date")
b_dirname=$(detect_binary "dirname")
b_find=$(detect_binary "find")
b_grep=$(detect_binary "grep")
b_head=$(detect_binary "head")
b_id=$(detect_binary "id")
b_install=$(detect_binary "install")
b_mkdir=$(detect_binary "mkdir")
b_sed=$(detect_binary "sed")
b_stat=$(detect_binary "stat")
b_tr=$(detect_binary "tr")
b_uname=$(detect_binary "uname")
b_wc=$(detect_binary "wc")

red="\033[1;31m"
amber="\033[1;33m"
green="\033[1;32m"
white="\033[1;37m"
normal="\033[0m"

db_list=""

EXCLUDE="\.svn|\.hg|\.cvs|\.git"
USER=$($b_id -un)
GROUP=$($b_id -gn)
IMODE="0644"
WRKDIR=$($b_grep $USER /etc/passwd | $b_head -1 | $b_awk -F: '{print $6}')
WRKDIR=$(echo $WRKDIR | $b_sed 's/\/$//g')
WRKDIR="${WRKDIR}/.cdeploy"
DESTDIR="/"
SIMMODE=0
IGNEXCL=0

MODE=1				# Default: interactive mode
LOGTO=stdout		# Default: write log messages to stdout
LOGLEVEL=2			# Default: only log messages with level "WARN" or above
					# 0 = DEBUG
					# 1 = INFO
					# 2 = WARN
					# 3 = ERROR

# if run on FreeBSD, the default is to call cap_mkdb
if [ "$($b_uname)" = "FreeBSD" ]
then
	MKDB=1
else
	MKDB=0
fi


# FUNCTIONS

show_usage() {
	local FLAGS="[-hnvDS] [-b backup-dir] [-d destdir] [-u user] [-g group] [-m mode]"
	if [ "${MODE}" -eq "1" ]; then
		local USG="${red}usage: ${green}$($b_basename ${0}) ${normal}${FLAGS}"
	else
		local USG="usage: $($b_basename ${0}) ${FLAGS}"
	fi
	echo -e "$USG

  -h              print this help
  -v              print version information
  -n              non-interactive mode: no escape sequences in output
  -D              do not invoke cap_mkdb for db template files
  -S              simulation mode. creates backups, but doesn't deploy files
  -X              ignore exclusion pattern
  -b backup-dir   create backups in <backup-dir>
  -d destdir      deploy configuration to <destdir>
  -l loglevel     set verbositiy to either DEBUG, INFO, WARN, or ERROR
  -u user         deploy as owner <user> if detection fails
  -g group        deploy as group <group> if detection fails
  -m mode         deploy with mode <mode> if detection fails
  -x pattern      exclude files matching <pattern> from deployment

Please report any issues like bugs etc. via the root-tools bug tracking
tool available at http://sourceforge.net/projects/root-tools/" >&2 && exit 0
}


show_version() {
	local revstring='$Id$'
	revstring=$(echo $revstring | $b_awk '{print $3}')
	local VERSION=""
	if [ -z "$VERSION" ]
	then
		local VER="development version r${revstring}"
	else
		local VER="$VERSION"
	fi
	echo "$($b_basename ${0}) ${VER}

Copyright (c) 2009 Jesco Freund <aihal@users.sourceforge.net>
License: ISCL: ISC License <http://www.opensource.org/licenses/isc-license.txt>
This is free software: you are free to change and redistribute ist.
There is NO WARRANTY, to the extent permitted by law.

Written by Jesco Freund." >&2 && exit 0
}


get_log_level() {
	case $1 in
		[dD][eE][bB][uU][gG])
			echo "0"
			;;
		[iI][nN][fF][oO])
			echo "1"
			;;
		[wW][aA][rR][nN])
			echo "2"
			;;
		[eE][rR][rR][oO][rR])
			echo "3"
			;;
		*)
			echo "-1"
			;;
	esac
}


log() {
	if [ "$(get_log_level $1)" -ge "$LOGLEVEL" ]; then
		local m_date="[$($b_date +'%Y-%m-%d %H:%M:%S')]"
		local m_level="$(echo $1 | $b_tr \"[:lower:]\" \"[:upper:]\")"
		local m_msg="$(echo $2 | $b_cut -c 1-1024)"
		if [ "$LOGTO" = "stdout" ]; then
			if [ "$MODE" -eq "1" ]; then
				case $m_level in
					DEBUG)
						m_level="\033[1;36m[DEBUG]\033[0m"
						;;
					INFO)
						m_level="\033[1;32m[INFO] \033[0m"
						;;
					WARN)
						m_level="\033[1;33m[WARN] \033[0m"
						;;
					ERROR)
						m_level="\033[1;31m[ERROR]\033[0m"
						;;
				esac
			else
				m_level="[${m_level}]"
			fi
			echo -e "$m_level ${m_msg}"
		else
			echo "$m_date [${m_level}] -- ${m_msg}" >> $LOGTO
		fi
	fi
}


# TEST ARGUMENTS

while [ "$#" -gt "0" ]
do
	case $1 in
		-h|--help)
			show_usage
			shift
			;;
		-v|--version)
			show_version
			shift
			;;
		-n)
			MODE=0
			red=""
			amber=""
			green=""
			white=""
			normal=""
			shift
			;;
		-D)
			MKDB=0
			shift
			;;
		-S)
			SIMMODE=1
			shift
			;;
		-X)
			IGNEXCL=1
			shift
			;;
		-b)
			if [ "$#" -gt "1" ]
			then
				if [ -d "$2" ]
				then
					if [ -w "$2" ]
					then
						WRKDIR=$(echo $2 | $b_sed 's/\/$//g')
						log DEBUG "Working directory for backups set to $WRKDIR"
					else
						log ERROR "cannot write to $2 (no permission)"
						exit 1
					fi
				else
					WRKDIR=$(echo $2 | $b_sed 's\/$//g')
				fi
			else
				log ERROR "No argument supplied for -b."
				exit 1
			fi
			shift 2
			;;
		-d)
			if [ "$#" -gt "1" ]
			then
				if [ -d "$2" ]
				then
					DESTDIR=$(echo $2 | $b_sed 's/\/$//g')
					log DEBUG "Deployment destination set to $DESTDIR"
				else
					log ERROR "$2 is not a valid directory"
					exit 1
				fi
			else
				log ERROR "No argument supplied for -d."
				exit 1
			fi
			shift 2
			;;
		-l)
			if [ "$#" -gt "1" ]
			then
				if [ "$(get_log_level $2)" -ge "0" ]
				then
					LOGLEVEL=$(get_log_level $2)
				else
					log ERROR "$2 is not a valid log level."
					exit 1
				fi
			else
				log ERROR "No argument supplied for -l."
				exit 1
			fi
			shift 2
			;;
		-u)
			if [ "$#" -gt "1" ]
			then
				{ ut=$($b_id $2); } 2>/dev/null
				if [ -z "$ut" ]
				then
					log ERROR "$2 is not a valid system user."
					exit 1
				else
					USER=$2
					log DEBUG "User for deployment is set to $USER"
				fi
			else
				log ERROR "No argument supplied for -u."
				exit 1
			fi
			shift 2
			;;
		-g)
			if [ "$#" -gt "1" ]
			then
				gt="0"
				gt=$($b_grep "^$2" /etc/group | $b_wc -l)
				if [ -z "$gt" -o "$2" -lt "1" ]
				then
					log ERROR "$2 is not a valid group."
					exit 1
				else
					GROUP=$2
					log DEBUG "Group for deployment is set to $GROUP"
				fi
			else
				log ERROR "No argument supplied for -g."
				exit 1
			fi
			shift 2
			;;
		-m)
			if [ "$#" -gt "1" ]
			then
				IMODE=$2
				log DEBUG "Mode for deployment is set to $IMODE"
			else
				log ERROR "No argument supplied for -m."
				exit 1
			fi
			shift 2
			;;
		-x)
			if [ "$#" -gt "1" ]
			then
				EXCLUDE=$2
				log DEBUG "Exclusion pattern set to $EXCLUDE"
			else
				log ERROR "No argument supplied for -x."
				exit 1
			fi
			shift 2
			;;
		*)
			log ERROR "unknown option: $1"
			exit 1
			;;
	esac
done


# create working directory if it does not exist yet
if [ ! -d "${WRKDIR}" ]
then
	log DEBUG "$WRKDIR does not exist. trying to create it... "
	{ $b_mkdir ${WRKDIR}; } > /dev/null 2>/dev/null
	if [ "$?" -ne "0" ]
	then
		log ERROR "Failed to create working directory at $WRKDIR"
		exit 1
	else
		log DEBUG "Working directory successfully created."
	fi
fi


# create backup location
location=$($b_date "+${WRKDIR}/%Y%m%d-%H%M%S")
echo -n "creating backup directory in ${location} ... "
{ $b_mkdir $location; } >/dev/null 2>/dev/null
if [ "$?" -ne "0" ]
then
	echo -e "${red}failed${normal}"
	exit 1
else
	echo -e "${green}success${normal}"
fi

if [ "$IGNEXCL" -eq "0" ]
then
	candidates=$($b_find . -type f | $b_grep -E -v ${EXCLUDE})
else
	candidates=$($b_find . -type f)
fi

for i in $candidates
do
	orig=$(echo $i | $b_sed 's/^\.//')
	if [ ! "$DESTDIR" = "/" ]
	then
		orig="${DESTDIR}${orig}"
	fi
	odir=$($b_dirname $orig)
	if [ "$SIMMODE" -eq "0" ]
	then
		echo -n "deploying $($b_basename $i) to ${orig} ... "
	else
		echo -n "simulating deployment of $($b_basename $i) to ${orig} ... "
	fi

	# is this file a template for a db file?
	if [ -f "${orig}.db" -a "$MKDB" -gt "0" ]
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
		user=$USER
		group=$GROUP
		mode=$IMODE
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
	if [ "$SIMMODE" -eq "0" ]
	then
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
	else
		# test for caveats
		idir=$($b_dirname $orig)
		if [ ! -d "$idir" ]
		then
			if [ ! -d $($b_dirname $idir) ]
			then
				# target directory does not exist and can possibly not be created
				echo -e "${amber}warning${normal}"
			else
				if [ -w $($b_dirname $idir) ]
				then
					# Parent directory exists and is writeable
					echo -e "${green}success${normal}"
				else
					# Parent directory exists, but is not writeable
					log DEBUG "Cannot write to $($b_dirname $idir)."
					echo -e "${red}failed${normal}"
				fi
			fi
		else
			if [ -w "$idir" ]
			then
				# target directory exists and is writeable
				echo -e "${green}success${normal}"
			else
				# target directory exists, but is not writeable
				log DEBUG "Cannot write to ${idir}."
				echo -e "${red}failed${normal}"
			fi
		fi
	fi

done

# re-create .db files if necessary...
if [ "$MKDB" -gt "0" ]
then
	for i in $db_list
	do
		if [ "$SIMMODE" -eq "0" ]
		then
			echo -n "refreshing db file for $i ... "
			{ $b_cap $i; } >/dev/null 2>/dev/null
			if [ "$?" -ne "0" ]
			then
				echo -e "${red}failed${normal}"
			else
				echo -e "${green}success${normal}"
			fi
		else
			echo -n "simulating refresh of db file for $i ... "
			if [ -z "$b_cap" ]
			then
				echo -e "${red}failed${normal}"
			else
				echo -e "${green}success${normal}"
			fi
		fi
	done
fi

exit 0	
