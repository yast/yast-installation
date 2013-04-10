#!/bin/sh

function x86_64_check_x11 () {
    # fbdev driver doesn't work on top of mgag200 KMS driver
    if [ -r /proc/fb ]; then
	if cat /proc/fb | grep -q mgadrmfb; then
	    log "\t Use modesetting driver on Matrox hardware"
	    export XServerAccel=modesetting
	    export acceleratedx=1
	fi
    fi
}
