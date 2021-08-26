# test/data/proc-mounts

This directory contains /proc/mounts files that were collected during an
installation. The intended purpose is for testing the Unmounter class, but they
may also be useful for other tests.

All files named proc-mounts*-raw.txt are as taken directly from the system, the
-pretty.txt variant is just formatted prettier (using `column -t`), and it
contains some comment lines at the start to describe the scenario.

`/proc/mounts` doesn't normally include comments, but the Unmounter class can
handle comments and empty lines.

Most scenarios include the partitions of the target system mounted below
`/mnt`.


