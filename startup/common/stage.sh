#!/bin/sh
#================
# FILE          : stage.sh
#----------------
# PROJECT       : YaST (Yet another Setup Tool v2)
# COPYRIGHT     : (c) 2004 SUSE Linux AG, Germany. All rights reserved
#               :
# AUTHORS       : Marcus Schaefer <ms@suse.de> 
#               :
#               :
# BELONGS TO    : System installation and Administration
#               :
# DESCRIPTION   : Stage functions for YaST2. The first and second
#               : stage level code has been separated into numbered
#               : stage scripts. The prefix for the First-Stage
#               : is FXX_name.sh whereas the prefix SXX_name.sh is
#               : used for the Second-Stage scripts
#               :
#               :
# STATUS        : $Id$
#----------------
#
#----[ createStageList ]-----#
function createStageList () {
#-----------------------------------------------
# create a sorted list of script names refering
# to the given prefix. The result is saved as array
# named: STAGE_LIST
# ---
	PREFIX_LOOKUP=$1
	STAGE_DIR=$2
	STAGE_LIST=() 
	if [ -z $PREFIX_LOOKUP ];then
		return
	fi
	if [ ! -d $STAGE_DIR ];then
		return
	fi
	for file in $STAGE_DIR/*;do
		BASEFILE=`basename $file`
		if [ ! -f $file ];then
			continue
		fi
		case $BASEFILE in
			[FS%][0-9][0-9]*)
				PREFIX=`echo $BASEFILE | cut -c1`
				INDEX=`echo $BASEFILE | cut -c2-3 | sed -e s@^0@@`
			;;
			*)
				log "\tUnknown stage entry: $BASEFILE... ignored"
				continue
			;;
		esac
		if [ "$PREFIX" = "$PREFIX_LOOKUP" ] || [ "$PREFIX_LOOKUP" = "%" ];then
			while true;do
				if [ -z ${STAGE_LIST[$INDEX]} ];then
					STAGE_LIST[$INDEX]=$file
					break
				fi
				INDEX=$((INDEX + 1))
			done
		fi
	done
}

#----[ callStages ]--------#
function callStages () {
#-----------------------------------------------
# call the scripts saved in STAGE_LIST
# ---
	for file in ${STAGE_LIST[*]};do
		if [ -x $file ];then
			. $file
		fi
	done
}

#----[ callHooks ]--------#
function callHooks () {
#-----------------------------------------------
# call the hook scripts according to the given
# directory name
#
	if [ -d /usr/lib/YaST2/startup/hooks/$1 ];then
		log "\tCreating hook script list: $1..."
		createStageList "%" "/usr/lib/YaST2/startup/hooks/$1"
		callStages
	fi
}
