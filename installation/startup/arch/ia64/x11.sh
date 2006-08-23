#!/bin/sh

function ia64_check_x11 () {
	[ -n "$HOSTTYPE" ] || HOSTTYPE=$(arch)
	if [ "$HOSTTYPE" = "ia64" ];then
		log "\tArchitecture dependant: use accelerated driver on ia64"
		export acceleratedx=1
	fi
}
