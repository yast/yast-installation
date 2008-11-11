#!/bin/sh

function i386_check_x11 () {
	if lspci -n | grep "0300: 8086" | \
           grep -q -E "7121|7123|7125|1132"; then
		log "\tHardware dependent: use accelerated driver on Intel 810/815"
		export acceleratedx=1
	fi
}
