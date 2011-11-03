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
	if [ ! -e /root/.vnc/passwd.yast ]; then
		rm -rf /root/.vnc && mkdir -p /root/.vnc
		$VNCPASS /root/.vnc/passwd.yast "$VNCPassword"
		if [ $? = 0 ];then
			chmod 600 /root/.vnc/passwd.yast
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
	# The IP set in install.inf may not be valid if the DHCP server
	# gave us a different lease in the meantime (#43974).

	echo
	echo starting VNC server...
	echo A log file will be written to: /var/log/YaST2/vncserver.log ...
	cat <<-EOF

	***
	***           You can connect to <host>, display :1 now with vncviewer
	***           Or use a Java capable browser on http://<host>:5801/
	***

	(When YaST2 is finished, close your VNC viewer and return to this window.)

	Active interfaces:

	EOF
	list_ifaces
	echo

	#==========================================
	# Start Xvnc...
	# For -noreset see BNC #351338
	#------------------------------------------
	$Xbindir/Xvnc $Xvncparam :0 \
		-noreset \
		-rfbauth /root/.vnc/passwd.yast \
		-desktop "Installation" \
		-geometry 800x600 \
		-depth 16 \
		-rfbwait 120000 \
		-httpd /usr/share/vnc/classes \
		-rfbport 5901 \
		-httpport 5801 \
		-fp $Xfontdir/misc/,$Xfontdir/uni/,$Xfontdir/truetype/ \
	&> /var/log/YaST2/vncserver.log &
	xserver_pid=$!
	export DISPLAY=:0
	export XCURSOR_CORE=1
}
