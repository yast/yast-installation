#!/bin/sh

function s390_check_need_initvicons () {
	[ -n "$HOSTTYPE" ] || HOSTTYPE=$(arch)
	if [ "$HOSTTYPE" = "s390" ];then
		export NEED_INITVICONS="no"
		return
	fi
	if [ "$HOSTTYPE" = "s390x" ];then
		export NEED_INITVICONS="no"
		return
	fi
	export NEED_INITVICONS="yes"
}
