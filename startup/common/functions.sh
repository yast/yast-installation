#================
# FILE          : functions.sh
#----------------
# PROJECT       : YaST (Yet another Setup Tool v2)
# COPYRIGHT     : (c) 2004 SUSE Linux AG, Germany. All rights reserved
#               :
# AUTHORS       : Marcus Schaefer <ms@suse.de> 
#               :
#               :
# BELONGS TO    : System installation and Administration
#               :
# DESCRIPTION   : Common used functions for YaST2 startup
#               : 
#               :
# STATUS        : $Id$
#----------------
#
#=============================================
# 1) Source common YaST2 script functions
#---------------------------------------------
. /usr/lib/YaST2/bin/yast2-funcs

#=============================================
# 2) Source common Startup script functions
#---------------------------------------------
. /usr/lib/YaST2/startup/common/misc.sh
. /usr/lib/YaST2/startup/common/network.sh
. /usr/lib/YaST2/startup/common/logging.sh
. /usr/lib/YaST2/startup/common/language.sh
. /usr/lib/YaST2/startup/common/arch.sh
. /usr/lib/YaST2/startup/common/stage.sh
. /usr/lib/YaST2/startup/common/vnc.sh
