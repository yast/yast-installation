#================
# FILE          : network.sh
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
#               : refering to network environment issues
#               :
# STATUS        : $Id$
#----------------
#
#----[ is_iface_up ]-----#
function is_iface_up () {
#--------------------------------------------------
# check if given interface is up
# ---
	test -z "$1" && return 1
	case "`LC_ALL=POSIX ip link show $1 2>/dev/null`" in
		*$1*UP*) ;;
		*) return 1 ;;
	esac
}

#----[ found_iface ]-----#
function found_iface () {
#--------------------------------------------------
# search for a queued network interface
#
	for i in `ip -o link show | cut -f2 -d:`;do
		iface=`echo $i | tr -d " "`
		if is_iface_up "$iface" ; then
			return 0
		fi
	done
	return 1
}


function list_ifaces()
{
    # list network interfaces
    # - all active ones with all IPv4 / IPv6 addresses
    # - excluding loopback device
    /sbin/ip -o a s | grep "inet" | cut -d' ' -f2 | uniq | grep -v "^lo" | xargs -n1 -d'\n' /sbin/ip a s
}


#----[ vnc_message ]-----#
function vnc_message () {
#--------------------------------------------------
# console message displayed with a VNC installation
# ---
	cat <<-EOF
	
	***
	***  Please return to your X-Server screen to finish installation
	***
	
	EOF
}

#----[ ssh_message ]-----#
function ssh_message () {
#--------------------------------------------------
# console message displayed with a SSH installation
# ---
	cat <<-EOF
	
	***  sshd has been started  ***
	
	you can login now and proceed with the installation
	run the command 'yast.ssh'
	
	active interfaces:
	
	EOF
	list_ifaces
	echo
}
