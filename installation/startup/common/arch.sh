#================
# FILE          : arch.sh
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
#               : refering to architecture issues
#               :
# STATUS        : $Id$
#----------------
#
#----[ is_iseries ]-----#
function is_iseries () {
#--------------------------------------------------
# check if CPU is a PPC iseries component
# ---
	grep -iq iseries /proc/cpuinfo
}

