#================
# FILE          : logging.sh
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
#               : refering to logging issues
#               :
# STATUS        : $Id$
#----------------
#
#----[ set_syslog ]-----#
function set_syslog() {
#--------------------------------------------------
# if Loghost: is set in install.inf create new
# log.conf for YaST2 syslog and restart syslog via
# HUP signal
# ---
	if [ -f /etc/install.inf ];then
		Loghost=$(awk ' /^Loghost:/ { print $2 }' < /etc/install.inf)
		test ! -z $Loghost && {
			mkdir -p /etc/YaST2
			cat <<-EOF > /etc/YaST2/log.conf
				[Log]
				file = true
				syslog = true
			EOF
			grep -iwq y2debug < /proc/cmdline && {
				echo "debug=true" >> /etc/YaST2/log.conf
			}
			echo "*.* @$Loghost" >> /etc/syslog.conf
			kill -HUP `cat /var/run/syslogd.pid`
		}
	fi
}

#----[ log ]------------#
function log {
#--------------------------------------------------
# helper function to write special startup log file
# /var/log/YaST2/y2start.log
# ---
	if [ "`echo -e "$@" | cut -c1`" = "	" ];then
		msg=`echo $@ | cut -c 3-`
		echo -e "\t|-- $msg" >> /var/log/YaST2/y2start.log
	else
		echo "$LOG_PREFIX: $@" >> /var/log/YaST2/y2start.log
	fi
}

#---[ fatalError ]----#
function fatalError () {
#--------------------------------------------------
# an error situation exists and there is no way out
# sleeping forever
# ---
	echo "*** Fatal Error occured, process stopped ***"
	echo "- Commandline available at <Alt-F2>"
	echo "- Further information written to:"
	echo "  /var/log/YaST2/y2start.log"
	while true;do
		read
	done
}
