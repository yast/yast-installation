In the initial installation system, yast2 perform the following
actions:

- Prepare the target disk (fdisk, mke2fs, ...)
- Install the packages from the first CD
- if the source is remountable, install the other packages

Now the root filesystem is remounted, the new target is
used as root. If yast2 want's to be run again, it has created
the file /var/lib/YaST2/runme_at_boot. YaST2 is then started
as last action of /etc/init.d/boot.


