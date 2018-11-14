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

	    case "$LANG" in
		ar_EG*|bn_BD*|gu_IN*|hi_IN*|km_KH*|mr_IN*|pa_IN*|ta_IN*|th_TH*)
		    export LANG=en_US.UTF-8
		    export LC_CTYPE=en_US.UTF-8
	    esac
	fi
}

#----[ set_language_init ]----#
function set_language_init () {
#--------------------------------------------------
# setup LANG variable to a UTF-8 locale
# this code only works in first stage (init)
# ---
        # append UTF-8
        [ "$LANGUAGE" ] && LANG="${LANGUAGE%%.*}.UTF-8"
}

#----[ set_language_cont ]----#
function set_language_cont () {
#--------------------------------------------------
# setup LANG variable to a UTF-8 locale
# This code only works in second stage (continue)
# ---
        if [ -z "$RC_LANG" ]; then
                log "\tRC_LANG not set, using en_US as default..."
                export RC_LANG=en_US
        fi

        # get rid of encoding and/or modifier
        export LANG=${RC_LANG%%[.@]*}.UTF-8
}

#----[ start_unicode ]-----#
function start_unicode () {
#--------------------------------------------------
# start unicode mode if LANG is a UTF-8 locale
# ---
	if [ ! -x /bin/unicode_start ] ; then
		return
	fi

	# unicode_starts/stop should only be called on consoles, see bnc #800790
	TTY=`/usr/bin/tty`
	if [ "$TTY" != "/dev/console" -a "$TTY" == "${TTY#/dev/tty[0-9]}" ] ; then
		return
	fi

	if echo $LANG | grep -q '\.UTF-8$' ; then
		log "\tStarting UTF-8 mode..."
		unicode_start
	fi
}

#----[ stop_unicode ]-----#
function stop_unicode () {
#--------------------------------------------------
# stop unicode mode if LANG is a UTF-8 locale
# ---
	if [ ! -x /bin/unicode_stop ] ; then
		return
	fi

	# unicode_start/stop should only be called on consoles, see bnc #800790
	TTY=`/usr/bin/tty`
	if [ "$TTY" != "/dev/console" -a "$TTY" == "${TTY#/dev/tty[0-9]}" ] ; then
		return
	fi

	if echo $LANG | grep -q '\.UTF-8$' ; then
		log "\tStopping UTF-8 mode..."
		unicode_stop
	fi
}
