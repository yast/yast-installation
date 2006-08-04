#!/bin/sh
#================
# FILE          : vnc.sh
#----------------
# PROJECT       : YaST (Yet another Setup Tool v2)
# COPYRIGHT     : (c) 2004 SUSE Linux AG, Germany. All rights reserved
#               :
# AUTHORS       : Marcus Schaefer <ms@suse.de> 
#               :
#               :
# BELONGS TO    : System installation and Administration
#               :
# DESCRIPTION   : VNC helper functions to start the Xvnc server
#               :
#               :
# STATUS        : $Id$
#----------------

. /etc/YaST2/XVersion

#----[ setupVNCAuthentication ]------#
function setupVNCAuthentication () {
#---------------------------------------------------
# handle the VNCPassword variable to create a valid
# password file.
#
	VNCPASS_EXCEPTION=0
	VNCPASS=$Xbindir/vncpasswd.arg
	if [ ! -e /root/.vnc/passwd ]; then
		rm -rf /root/.vnc && mkdir -p /root/.vnc
		$VNCPASS /root/.vnc/passwd "$VNCPassword"
		if [ $? = 0 ];then
			chmod 600 /root/.vnc/passwd
		else
			log "\tcouldn't create VNC password file..."
			VNCPASS_EXCEPTION=1
		fi
	fi
}

#----[ startVNCServer ]------#
function startVNCServer () {
#---------------------------------------------------
# start Xvnc server and write a log file from the
# VNC server process
#
	# .../
	# The IP set in install.inf may not be valid if the DHCP server
	# gave us a different lease in the meantime (#43974).
	# sed: don't print; if it's localhost, skip; try locating IPv4;
	#      skip if not found; otherwise print and exit
	# ----
	IP=`ip addr list | sed -n \
		-e '/127.0.0.1/b;s/^[[:space:]]*inet[[:space:]]\([^/]*\).*/\1/;T;p;q'`

	echo
	echo starting VNC server...
	echo A log file will be written to: /var/log/YaST2/vncserver.log ...
	cat <<-EOF
	
	***
	***           You can connect to $IP, display :1 now with vncviewer
	***           Or use a Java capable browser on  http://$IP:5801/
	***
	
	(When YaST2 is finished, close your VNC viewer and return to this window.)
	
	EOF
	#==========================================
	# Fake hostname to make VNC screen pretty
	#------------------------------------------
	if [ "$(hostname)" = "(none)" ] ; then
		hostname $IP
	fi
	#==========================================
	# Start Xvnc...
	#------------------------------------------
	$Xbindir/Xvnc :0 \
		-rfbauth /root/.vnc/passwd \
		-desktop Installation \
		-geometry 800x600 \
		-depth 16 \
		-rfbwait 120000 \
		-httpd /usr/share/vnc/classes \
		-rfbport 5901 \
		-httpport 5801 \
		-fp $Xlibdir/X11/fonts/misc/,$Xlibdir/X11/fonts/uni/,$Xlibdir/X11/fonts/truetype/ \
	&> /var/log/YaST2/vncserver.log &
	xserver_pid=$!
	export DISPLAY=:0
	export XCURSOR_CORE=1
}
