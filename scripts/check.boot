#!/bin/bash
OD=`/usr/bin/od --address-radix=d --skip-bytes=510 --read-bytes=2 -h $1 | 
    sed -e "s/^.* //" -e '2,$d'`
[ "$OD" = aa55 ]
exit $?
