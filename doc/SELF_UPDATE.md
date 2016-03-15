# Installer self-update

Starting on version 3.1.175, yast2-install is able to update itself during
system installation. This feature will help to solve problems with the
installation even after the media has been released. Check
[FATE#319716](https://fate.suse.com/319716) for a more in-depth rationale.

## Disabling updates

Self-update is enabled by default. However, it can be disabled setting
`self_update=0` in Linuxrc.

## Basic workflow

These are the basic steps performed by YaST in order to peform the update:

1. During installation, YaST will look automatically for an update in a given
   URL.
2. If an update is available, it will be downloaded. Otherwise,
   the process will be silently skipped.
3. The update's GPG signature will be verified.
4. The update will be applied to the installation system as a regular
   DUD.
5. YaST will be restarted and the installation will be resumed.

## Update format

YaST will use a Driver Update Disks (DUD) to pack the updates. To minimize
bandwidth and memory usage, all updates should be contained in a single DUD.
Moreover, to make maintenance of this feature simpler, the only allowed archive
format to use is `cpio` (default format for
[mkdud](https://github.com/openSUSE/mkdud)).

You can find more information about DUDs in [The Update Media
HOWTO](http://ftp.suse.com/pub/people/hvogel/Update-Media-HOWTO/index.html) and
in the [Linuxrc page](http://en.opensuse.org/SDB:Linuxrc#p_driverupdate]) in
the openSUSE wiki.

## Where to find updates

Update's URL can be hard-coded in `control.xml` file or specified setting
`SelfUpdate` option in Linuxrc.

The URL can contain a variable `$arch` that will be replaced by the system's
architecture, such as `x86_64`, `s390x`, etc. You can find more information
in the [Arch module](http://www.rubydoc.info/github/yast/yast-yast2/Yast/ArchClass).

```xml
<globals>
  <self_update_url>http://updates.suse.com/sle12/$arch/update.dud</self_update_url>
</globals>
```

## Security

Official updates should be GPG-signed. YaST will check the signature using
the `installkey.gpg` keyring that it's present in the installation media.
If the signature is not correct, the user will be asked wherther she/he
wants to apply the update (although it's a security risk).

Signature checking can be ignored setting `insecure=1` in Linuxrc prompt.
