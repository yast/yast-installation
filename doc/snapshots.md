# Installation and upgrade snapshots

This document tries to clarify how YaST, as an installer, creates snapshots during installation and
offline upgrade when Snapper is enabled. In a nutshell, YaST creates these snapshots:

* A *single* snapshot at the end of the installation (except for transactional systems, like
  MicroOS).
* A *pre* snapshot at the beginning of the upgrade and a *post* snapshot at the end.

However, things are not that simple, so let's try to draw a full picture of this feature.

## Non-transactional systems

Let's start considering non transactional systems, like SUSE Linux Enterprise, openSUSE Leap or
openSUSE Tumbleweed. Remember that you can use openSUSE Tumbleweed as a transactional system if
you select the *Transactional Server* role during installation.

### Installation

YaST creates a snapshot after *finishing* the normal installation. If you are using AutoYaST, it
takes the snapshot at the end of the 2nd stage *unless it is disabled*. If the 2nd stage is
disabled, YaST takes the snapshot at the end of the 1st stage, just like a normal installation.

If you run `snapper list` in your just installed system, you should see something like this:

```
# snapper list
 # | Type   | Pre # | Date                     | User | Used Space | Cleanup | Description           | Userdata     
---+--------+-------+--------------------------+------+------------+---------+-----------------------+--------------
0  | single |       |                          | root |            |         | current               |              
1* | single |       | Fri Feb 18 06:06:17 2022 | root |  13.22 MiB |         | first root filesystem |              
2  | single |       | Fri Feb 18 06:12:22 2022 | root |   3.01 MiB | number  | after installation    | important=yes
```

Which is the role of each "snapshot"?

* Snapshot 0: it is created by Snapper during the initialization.
* Snapshot 1: it is the *current snapshot*. It is mounted as read/write and it is where your system
  lives.
* Snapshot 2: YaST created this snapshot at the end of the installation.

Your system runs on *snapshot 1*, and *snapshot 2* is just a way to travel back in time to the end
of the installation. We usually think about snapshots as *pictures* of the system on a given time,
but that is not an accurate definition.

### Offline Upgrade

During offline upgrade, YaST takes two different snapshots: one at the beginning of the installation
and another one at the end. Both snapshots are related as you can see in the table below:

```
# snapper list
 # | Type   | Pre # | Date                     | User | Used Space | Cleanup | Description           | Userdata     
---+--------+-------+--------------------------+------+------------+---------+-----------------------+--------------
0  | single |       |                          | root |            |         | current               |              
1* | single |       | Fri Feb 18 06:06:17 2022 | root |  13.22 MiB |         | first root filesystem |              
2  | single |       | Fri Feb 18 06:12:22 2022 | root |   3.01 MiB | number  | after installation    | important=yes
3  | pre    |       | Fri Feb 18 10:40:05 2022 | root |  36.63 MiB | number  | zypp(zypper)          | important=yes
4  | post   |     3 | Fri Feb 18 10:55:11 2022 | root |  16.11 MiB | number  |                       | important=yes
5  | pre    |       | Fri Feb 18 13:36:49 2022 | root |  14.91 MiB | number  | before update         | important=yes
6  | post   |     5 | Fri Feb 18 14:01:59 2022 | root |   2.45 MiB | number  | after update          | important=yes
```

According to the table above, YaST created snapshot 5 (*pre*) before starting the upgrade process
and snapshot 6 (*post*) at the end. However, snapshot 1 is still the root file system.

## Transactional systems

Transactional systems, like MicroOS or the *Transactional Server* role of openSUSE Tumbleweed, take
care of their own snapshots. In those cases, YaST does not perform any snapshot at the end of the
installation. About the offline upgrade, using YaST to upgrade those systems is not supported.

Starting in yast2-installation 4.3.45, YaST detects if it is installing a transactional system by
checking whether the root filesystem is mounted as read-only.

## Related features

[FATE#317932](https://w3.suse.de/~lpechacek/fate-archive/317973.html) and SLE-22560.
