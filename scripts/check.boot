#!/bin/bash
/usr/bin/od --address-radix=d --skip-bytes=510 --read-bytes=2 -h $1 > /tmp/boot.found
/bin/echo "0000510 aa55" > /tmp/boot.expected
/bin/echo "0000512" >> /tmp/boot.expected
/usr/bin/diff /tmp/boot.found /tmp/boot.expected
result=$?
/bin/rm -f /tmp/boot.found /tmp/boot.expected
exit $result
