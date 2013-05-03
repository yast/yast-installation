#!/bin/sh

function s390_check_need_initviocons () {
	[ -n "$HOSTTYPE" ] || HOSTTYPE=$(arch)
	if [ "$HOSTTYPE" = "s390" ];then
		export NEED_INITVIOCONS="no"
		return
	fi
	if [ "$HOSTTYPE" = "s390x" ];then
		export NEED_INITVIOCONS="no"
		return
	fi
	export NEED_INITVIOCONS="yes"
}
