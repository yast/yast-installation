#!/bin/sh

function i386_check_x11 () {
	if test -x /sbin/lspci && /sbin/lspci -n | grep -q "0300: 8086"; then
		log "\tHardware dependent: use accelerated driver on Intel hardware"
		export acceleratedx=1
	fi
}
