#!/bin/bash
#================
# FILE          : misc.sh
#----------------
# PROJECT       : YaST (Yet another Setup Tool v2)
# COPYRIGHT     : (c) 2004 SUSE Linux AG, Germany. All rights reserved
#               :
# AUTHORS       : Marcus Schaefer <ms@suse.de>
#               :
#               :
# BELONGS TO    : System installation and Administration
#               :
# DESCRIPTION   : Common used functions for the YaST2 startup process
#               : refering to miscellaneous stuff
#               :
# STATUS        : $Id$
#----------------
#
#----[ set_proxy ]------#
function set_proxy() {
#--------------------------------------------------
# If Proxy: is set in install.inf export the env
# variables for http_proxy and ftp_proxy
# ---
	if [ "$ProxyURL" ] ; then
		export http_proxy="$ProxyURL"
		export ftp_proxy="$ProxyURL"
	fi
}

#----[ import_install_inf ]----#
function import_install_inf () {
#--------------------------------------------------
# import install.inf information as environment
# variables to the current environment
# ---
	TERM_SAVE=$TERM
	if [ -f /etc/install.inf ];then
	#eval $(
	#	grep ': ' /etc/install.inf |\
	#	sed -e 's/"/"\\""/g' -e 's/:  */="/' -e 's/$/"/'
	#)
	IFS_SAVE=$IFS
IFS="
"
	for i in `cat /etc/install.inf | sed -e s'@: @%@'`;do
		varname=`echo $i | cut -f 1 -d% | tr -d " "`
		varvals=`echo $i | cut -f 2 -d%`
		varvals=`echo $varvals | sed -e s'@^ *@@' -e s'@ *$@@'`
		export $varname=$varvals
	done
	IFS=$IFS_SAVE
	# /.../
	# if the installation is ssh based, TERM is not allowed to
	# be overwritten by the value of install.inf. The TERM value
	# of install.inf points to the console and not to the remote
	# terminal type. Therefore the previously set terminal type
	# from the remote terminal is restored
	# ----
	if [ "$UseSSH" = 1 ];then
		export TERM=$TERM_SAVE
	fi
	fi
}

#----[ ask_for_term ]----#
function ask_for_term () {
#--------------------------------------------------
# for serial console installation only. Create a
# menu to be able to choose a specific terminal
# type
#
	unset TERM
	echo -e "\033c"

	while test -z "$TERM" ; do
	echo ""
	echo "What type of terminal do you have ?"
	echo ""
	echo "  1) VT100"
	echo "  2) VT102"
	echo "  3) VT220$HVC_CONSOLE_HINT"
	echo "  4) X Terminal Emulator (xterm)"
	echo "  5) X Terminal Emulator (xterm-vt220)"
	echo "  6) X Terminal Emulator (xterm-sun)"
	echo "  7) screen session"
	echo "  8) Linux VGA or Framebuffer Console"
	echo "  9) Other"
	echo ""
	echo -n "Type the number of your choice and press Return: "
	read SELECTION
	case $SELECTION in
		1)
			TERM=vt100
			;;
		2)
			TERM=vt102
			;;
		3)
			TERM=vt220
			;;
		4)
			TERM=xterm
			;;
		5)
			TERM=xterm-vt200
			;;
		6)
			TERM=xterm-sun
			;;
		7)
			TERM=screen
			;;
		8)
			TERM=linux
			;;
		9)
			echo ""
			echo ""
			echo "Specify a valid terminal type exactly as it is listed in the"
			echo "terminfo database."
			echo ""
			echo -n "Terminal type: "
			read TERM
			;;
		*)
			echo ""
			echo ""
			echo "This selection was not correct, please try again!"
			;;
	esac
	done
	echo ""
	echo ""
	echo "Please wait while YaST2 will be started"
	echo ""
}

#----[ set_term_variable ]----#
function set_term_variable () {
#--------------------------------------------------
# set TERM variable and save it to /etc/install.inf
#
	if [ -z "$AutoYaST" ] && [ -z "$VNC" ] && [ -z "$UseSSH" ];then
		ask_for_term
		export TERM
	fi
	echo "TERM: $TERM" >> /etc/install.inf
}

#----[ got_kernel_param ]----#
function got_kernel_param () {
#--------------------------------------------------
# check for kernel parameter in /proc/cmdline
# ---
	tr " " "\n" </proc/cmdline | grep -qi "^$1$"
}

#----[ got_install_param ]----#
function got_install_param () {
#--------------------------------------------------
# check for install.inf parameter
# ---
	if [ -f /etc/install.inf ];then
		grep -qs $1 /etc/install.inf
	else
		return 1
	fi
}

#----[ set_splash ]-----#
function set_splash () {
#--------------------------------------------------
# set splash progressbar to a value given in $1
# ---
	[ -f /proc/splash ] && echo "show $(($1*65535/100))" > /proc/splash
	[ "$1" = 100 -a -x /sbin/splash ] && /sbin/splash -q
}

#----[ disable_splash ]-----#
function disable_splash () {
#--------------------------------------------------
# disable splash screen. This means be verbose and
# show the kernel messages
# ---
	[ -f /proc/splash ] && echo "verbose" > /proc/splash
}

#----[ stop_xvnc]-----#
function stop_xvnc () {
#--------------------------------------------------
# stop xvnc since its default configuration collides
# with the Xvnc server used for VNC installation
# ---
	systemctl stop xvnc.socket >/dev/null 2>&1
# stop also running instances of xvnc to allow start our own
        systemctl stop xvnc@* >/dev/null 2>&1
}

#----[ is_xvnc_enabled ]-----#
function is_xvnc_enabled () {
# return 0 if xvnc is enabled
# ---
	systemctl --quiet is-enabled xvnc.socket >/dev/null 2>&1
	return $?
}

#----[ restore_xvnc ]-----#
function restore_xvnc () {
#--------------------------------------------------
# start xvnc again if it is enabled, once the Xvnc
# server already owns its port
# ---
	if is_xvnc_enabled; then
		systemctl start xvnc.socket
	fi
}

#----[ have_pid ]----#
function have_pid () {
#------------------------------------------------------
# check if given PID is part of the process list
# ---
	kill -0 $1 2>/dev/null
}

#----[ load_module ]----#
function load_module () {
#------------------------------------------------------
# load a module using modprobe
# ---
	/sbin/modprobe $1
}

#----[ skip_initviocons ]----#
function skip_initviocons () {
#------------------------------------------------------
# check if the call to initviocons must be skipped
# ---
	# bnc #173426#c17: it is missing on single-CD repos
	if [ ! -x /bin/initviocons ] ; then
		return 0
	fi

	# initviocons should only be required on consoles, see bnc #800790
	TTY=`/usr/bin/tty`
	if [ "$TTY" != "/dev/console" -a "$TTY" == "${TTY#/dev/tty[0-9]}" ] ; then
		return 0
	fi

	grep -qw TERM /proc/cmdline && return 0 || return 1
}

function log_export()
{
    IFS_SAVE=$IFS
    IFS="
"
    for i in `export` ; do
        i=$(sed 's/\([^[:space:]]*\(repourl\|password\)\)=.*/\1="<\1 may contain sensitive information>"/i' <<< $i)
	log "\t$i"
    done
    IFS=$IFS_SAVE
}
