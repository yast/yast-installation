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
#----------------
#

#--------------------------------------------------
# Check whether the locale is supported in ncurses mode
# and fall back to en_US.UTF-8 if it is not
# ---
function check_supported_ncurses_locales () {
        TTY=`/usr/bin/tty`
	if test "$TERM" = "linux" -a \
		\( "$TTY" = /dev/console -o "$TTY" != "${TTY#/dev/tty[0-9]}" \);
	then
                # We are no longer using fbiterm to support nontrivial locales
                # (bsc#1224053), so we fall back to English if we are on the
                # system console

                case "$LANG" in
                        zh*|ja*|ko*|ar*|bn*|gu*|hi*|km*|mr*|pa*|ta*|th*)
                                log "\tLanguage $LANG is unsupported in NCurses, falling back to en_US.UTF-8"
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

        if [ "$RC_LANG" == "POSIX" ] || [ "$RC_LANG" == "C" ] ; then
                log "\tRC_LANG is ${RC_LANG}, using LANG en_US.UTF-8 as default..."
                export LANG=en_US.UTF-8
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
