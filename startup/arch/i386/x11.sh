#!/bin/sh

function i386_check_x11 () {
	[ -n "$HOSTTYPE" ] || HOSTTYPE=$(arch)
	if [ "$HOSTTYPE" == "s390" -o "$HOSTTYPE" == "s390x" ] ; then
		return
	fi
}
