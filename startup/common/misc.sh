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
	if [ -f /etc/install.inf ];then
	if grep -qs '^Proxy:.*' /etc/install.inf ; then
		Proxy=$(awk ' /^Proxy:/ { print $2 }' < /etc/install.inf)
		ProxyPort=$(awk ' /^ProxyPort:/ { print $2 }' < /etc/install.inf)
		ProxyProto=$(awk ' /^ProxyProto:/ { print $2 }' < /etc/install.inf)
		FullProxy="${ProxyProto}://${Proxy}:${ProxyPort}/"
		export http_proxy=$FullProxy
		export ftp_proxy=$FullProxy
	fi
	fi
}

#----[ import_install_inf ]----#
function import_install_inf () {
#--------------------------------------------------
# import install.inf information as environment
# variables to the current environment
# ---
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
	if [ -z "$AutoYaST" -a "$VNC" = 0 -a "$UseSSH" = 0 ]; then
		ask_for_term
		export TERM
		echo "TERM: $TERM" >> /etc/install.inf
	elif [ -a ! -z "$AutoYaST" -a "$VNC" != 0 -a "$UseSSH" != 0 ];then
		export TERM=vt100
		echo "TERM: $TERM" >> /etc/install.inf
	fi
}

#----[ got_kernel_param ]----#
function got_kernel_param () {
#--------------------------------------------------
# check for kernel parameter in /proc/cmdline
# ---
	grep -qi $1 < /proc/cmdline
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
	[ -f /proc/splash ] && echo "show $(($1*65534/100))" >/proc/splash
}

#----[ disable_splash ]-----#
function disable_splash () {
#--------------------------------------------------
# disable splash sceen. This means be verbose and
# show the kernel messages
# ---
	[ -f /proc/splash ] && echo "verbose" > /proc/splash
}

#----[ have_pid ]----#
function have_pid () {
#------------------------------------------------------
# check if given PID is part of the process list
# ---
	kill -0 $1 2>/dev/null
}
