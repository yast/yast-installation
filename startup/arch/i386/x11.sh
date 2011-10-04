#!/bin/sh

function i386_check_x11 () {
	[ -n "$HOSTTYPE" ] || HOSTTYPE=$(arch)
	if [ "$HOSTTYPE" == "s390" -o "$HOSTTYPE" == "s390x" ] ; then
		return
	fi
    
	if test -x /sbin/lspci && /sbin/lspci -n | grep -q "0300: 8086"; then
		log "\tHardware dependent: use accelerated driver on Intel hardware"
		export acceleratedx=1
	fi
}
