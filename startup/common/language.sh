#================
# FILE          : language.sh
#----------------
# PROJECT       : YaST (Yet another Setup Tool v2)
# COPYRIGHT     : (c) 2004 SUSE Linux AG, Germany. All rights reserved
#               :
# AUTHORS       : Marcus Schaefer <ms@suse.de> 
#               :
#               :
# BELONGS TO    : System installation and Administration
#               :
# DESCRIPTION   : Common used functions used for the YaST2 startup process
#               : refering to language environment issues
#               :
# STATUS        : $Id$
#----------------
#
#----[ check_run_fbiterm ]----#
function check_run_fbiterm () {
#--------------------------------------------------
# check whether the system can use fbiterm also
# handle the CJK language mangle on linux console
# set flag value in RUN_FBITERM
# ---
	RUN_FBITERM=0 
	if test "$MEM_TOTAL" -lt "57344" ; then
		return
	fi
	TTY=`/usr/bin/tty`
	if test "$TERM" = "linux" -a \
		\( "$TTY" = /dev/console -o "$TTY" != "${TTY#/dev/tty[0-9]}" \);
	then
		case "$LANG" in
		ja*.UTF-8|ko*.UTF-8|zh*.UTF-8)
		# check whether fbiterm can run on console
		if test -x /usr/bin/fbiterm && \
			/usr/bin/fbiterm echo >/dev/null 2>&1;
		then
			RUN_FBITERM=1
		else
			# use english
			export LANG=en_US.UTF-8
			export LC_CTYPE=en_US.UTF-8
		fi
		;;
		ja*|ko*|zh*)
		# use english
		export LANG=en_US.UTF-8
		export LC_CTYPE=en_US.UTF-8
		;;
	esac
	fi
}

#----[ set_language_init ]----#
function set_language_init () {
#--------------------------------------------------
# setup LANG variable to a UTF-8 locale if testutf8
# returns an appropriate exit code. This code only
# works in first stage (init)
# ---
	if [ "$Console" ]; then
		if testutf8 ; [ $? = 2 ] ; then
			# append UTF-8
			[ "$LANGUAGE" ] && LANG="${LANGUAGE%%.*}.UTF-8"
		else
			# don't use UTF-8 in case of a serial console
			[ "$LANGUAGE" ] && LANG=$LANGUAGE
		fi
	else
		# append UTF-8
		[ "$LANGUAGE" ] && LANG="${LANGUAGE%%.*}.UTF-8"
	fi
}

#----[ set_language_cont ]----#
function set_language_cont () {
#--------------------------------------------------
# setup LANG variable to a UTF-8 locale if testutf8
# returns an appropriate exit code. This code only
# works in second stage (continue)
# ---
	if [ "$Console" ]; then
		if testutf8 ; [ $? = 2 ] ; then
			# get rid of encoding and/or modifier
			export LANG=${RC_LANG%%[.@]*}.UTF-8
		else
			# don't use UTF-8 in case of a serial console
			export LANG=$RC_LANG
		fi
	else
		# get rid of encoding and/or modifier
		export LANG=${RC_LANG%%[.@]*}.UTF-8
	fi
}

#----[ start_unicode ]-----#
function start_unicode () {
#--------------------------------------------------
# start unicode mode if LANG is a UTF-8 locale
# ---
	if [ -f /bin/unicode_start ];then
	if echo $LANG | grep -q '\.UTF-8$'; then
		log "\tStarting UTF-8 mode..."
		unicode_start
	fi
	fi
}

#----[ stop_unicode ]-----#
function stop_unicode () {
#--------------------------------------------------
# stop unicode mode if LANG is a UTF-8 locale
# ---
	if [ -f /bin/unicode_stop ];then
	if echo $LANG | grep -q '\.UTF-8$'; then
		log "\tStopping UTF-8 mode..."
		unicode_stop
	fi
	fi
}

