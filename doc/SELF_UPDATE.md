# Installer Self-update

Starting on version 3.1.175, yast2-installation is able to update itself during
system installation. This feature will help to solve problems with the
installation even after the media has been released. Check
[FATE#319716](https://fate.suse.com/319716) for a more in-depth rationale.

### :information_source: Note

The self update feature is removed from the updated SLE Service Pack media
(the updated media released after the initial SP release), these media already
contain the updated installer and the included updates could conflict with
the self updates.

If you need to patch the installer on these updated media you have to use
a driver update disk (DUD).

## Disabling Updates

Starting in SUSE Linux Enterprise 12 SP3, self-update is enabled by default.
However, it can be disabled by setting `self_update=0` boot option. If you're
using AutoYaST, it is also possible to disable this feature using the
`self_update` element in the `general` section of the profile:

   ```xml
   <general>
     <self_update config:type="boolean">false</self_update>
   </general>
   ```

Please, take into account that self-update will be skipped if any option
disables it (boot parameter *or* AutoYaST profile).

During the rest of this document it is assumed that self-update is enabled.

## Basic Workflow

These are the basic steps performed by YaST in order to perform the update:

1. During installation, YaST will look automatically for a rpm-md repository
   containing the updates.
2. If updates are available, they will be downloaded. Otherwise, the process
   will be silently skipped.
3. The updates will be applied to the installation system, the meta-packages
   which are needed by the installer are copied to the inst-sys instead of
   applying.
4. YaST will be restarted to reload the modified files and the installation
   will be resumed.
5. The selected meta-packages copied to the inst-sys are added as an add-on
   installation repository to allow updating the `skelcd-*` or `*-release`
   packages via the self-update repository.

### Language Selection

The self-update step is executed before selecting the language
(`inst_complex_welcome` client). That means the self-update progress and
the errors which happens during the self-update process are by default displayed
in English.

To use another language also for the self-update press `F2` in the DVD boot menu
and select the language from the list. Or use the `language` boot option, e.g.
`language=de_DE`.

If you want to use a different keyboard layout for the console then use the
[`keytable`](https://en.opensuse.org/SDB:Linuxrc#p_keytable) boot option.

## Network Setup

Obviously, for downloading the installer updates YaST needs network.

YaST by default tries using DHCP on all network interfaces. If there is
a DHCP server in the network then network is configured automatically.

If you need static IP setup in your network then use the
`ifcfg=<interface>=<ip_address>,<gateway>,<nameserver>` boot option, e.g.
`ifcfg=eth0=192.168.1.101/24,192.168.1.1,192.168.1.2`.
See the [Linuxrc documentation](https://en.opensuse.org/SDB:Linuxrc#Network_Config)
for more details.

## Update Format

YaST will use RPM packages stored in a rpm-md repository, although they are
handled in a different way:

* All RPMs in the repository are considered (no "patch" metadata), only some
  meta-packages are skipped (e.g. the packages providing `system-installation()`
  or `product()`, it does not make sense to apply them to the inst-sys).
* RPMs are not installed in the usual way: they're uncompressed and no scripts
  are executed.
* No dependency checks are performed. RPMs are added in alphabetical order.

The rpm-md repository is required by SMT ([SUSE Subscription Management Tool](
https://www.suse.com/products/subscription-management-tool))
as this is the only format which it supports for data mirroring.

The files from the packages override the files from the original inst-sys.
That means the update packages might not need to contain all files,
it is enough to include only the changed files which are different than
in the original inst-sys. The unchanged files can be omitted to save memory
and the download bandwidth.

## Where to Find the Updates

The URL of the update repository is evaluated in this order:

1. The `self_update` boot option
   (Note: `self_update=0` completely disables the self-update!)
2. The AutoYaST profile - in AutoYaST installation only, use the
   `/general/self_update_url` XML node:

   ```xml
   <general>
     <self_update_url>http://example.com/updates/$arch</self_update_url>
   </general>
   ```
3. Registration server ([SCC](https://scc.suse.com) or
   [SMT](https://www.suse.com/products/subscription-management-tool)), not
   available in openSUSE. The URL of the registration server which should
   be used is determined via:
   1. The `regurl` boot parameter
   2. AutoYaST profile ([reg_server element](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Register)).
   3. SLP lookup (this behavior applies to regular and AutoYaST installations):
      * If at least one server is found it will ask the user to choose one.
      * In AutoYaST mode SLP is skipped unless enabled in the profile in the
        registration section (see [documentation](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#idm140139881100304)).
        AutoYaST expects that only one server is reported by SLP, if more
        servers are found it is considered as an error and user interaction is
        required just like in manual installation.
   4. Default SUSE Customer Center API (`https://scc.suse.com/`).

   The registration server is then asked for the list of update repositories.
   In order to determine such list, the product `name`, `version` and
   `architecture` are used

   In case of a multi-product installation medium, as the installer is the same
   for all the included products, the product `name` can be hard-coded in the
   `control.xml` file with the `/globals/self_update_id` XML node.

   ```xml
   <globals>
     <self_update_id>SLES</self_update_id>
   </globals>
   ```

4. Hard-coded in the `control.xml` file on the installation medium (thus it
   depends on the base product):

   ```xml
   <globals>
     <self_update_url>https://updates.suse.com/SUSE/Updates/SLE-INSTALLER/$os_release_version/$arch/update</self_update_url>
   </globals>
   ```

The first suitable URL will be used. There are two exceptions:

* If no update URL is found then the self-update is skipped.
* If SCC/SMT provides multiple URLs, they will be all used. Currently this is
  the only way how to use more update repositories.

### Downloading the AutoYaST Profile

As mentioned above, the self-update repository URL might be stored also in the
AutoYaST installation profile.

However, the self-update runs at the very beginning when some hardware might
not be initialized yet and therefore in some rare cases it might happen that the
self-updater is not able to load the profile eventhough it can be loaded
by the usual AutoYaST workflow later.

If that is the case you need to specify the custom update URL via `self_update`
boot option instead of specifying it in the profile.

### Manual SLP Discovery

If you want to check which SMT servers are announced locally via SLP you can
run this command: `slptool findsrvs registration.suse`.

Make sure the SLP communication is not blocked by firewall. Open UDP source port
427 if the firewall is running.

### Disabling SSL Certificate Check for SMT Server

When the used SMT server uses a self-signed SSL certificate for HTTPS conntections
YaST will ask to import that certificate. In that case you should verify the
certificate fingerprint before importing it.

If there are other issues with the certificate (signed by an unknown certificate
authority, expired certificate, ...) then you can disable the SSL check by
the `ptoptions=reg_ssl_verify reg_ssl_verify=0` boot options. But this is
a security risk and should be used only in a trusted network, using a valid
SSL certificate should be preferred.

### Variable Expansion

The URL can contain a variable `$arch` that will be replaced by the system's
architecture, such as `x86_64`, `i586`, `s390x`, etc.

YaST uses [libzypp](https://github.com/openSUSE/libzypp/blob/e68b5df6c96e3f1d140ba15e2a9e85a990210f37/zypp/ZConfig.cc#L63)
for detecting the system architecture so the `$arch` expansion is compatible
with the expansion used in usual repository URLs.

### Actual URLs

When using registration servers, the regular update URLs have the form
`https://updates.suse.com/SUSE/Updates/$PRODUCT/$VERSION/$ARCH/update` where
- PRODUCT is like OpenStack-Cloud, SLE-DESKTOP, SLE-SDK, SLE-SERVER,
- VERSION (for SLE-SERVER) is like 12, 12-SP1,
- ARCH is one of `aarch64` `ppc64le` `s390x` `x86_64`

For the self-update the *PRODUCT* is replaced
with *PRODUCT*-INSTALLER, producing these repository paths
under https://updates.suse.com/
- /SUSE/Updates/SLE-DESKTOP-INSTALLER/12-SP2/x86_64/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/aarch64/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/ppc64le/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/s390x/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/x86_64/update

## Security

### Package Integrity

Updates signatures will be checked by libzypp. If the signature is not
correct (or is missing), the user will be asked whether she/he wants to apply
the update (although it's a security risk).

When using AutoYaST, this behavior can be modified including the
[/general/signature-handling](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#idm140139881381840)
section in the profile.

### SLP Discovery

If SLP discovery is enabled, a popup is displayed to choose the server to use.
SLP by default does not use any authentication, everybody on the
local network can announce a registration server so it must be confirmed by user.

In AutoYaST mode SLP discovery must be enabled in the profile (in the
registration section) and it is expected that only one SLP server is present
in the network. If more servers are found the selection popup is displayed
even in the AutoYaST mode.

## Self-update and User Updates

Changes introduced by the user via Driver Updates (`dud` boot option) will take
precedence. As you may know, user driver updates are applied first (before the
self-update is performed).

However, the user changes will be re-applied on top of the installer updates.

## Resuming Installation

Any client called before the self-update step is responsible to remember its state (if
needed) and automatically going to the next dialog after the YaST restart.
Once the self-update step is reached again it will remove the restarting flag.

The self-update step is called very early in the workflow, for the self-update
step only configured network is needed. That is configured either by `linuxrc`
or by the `setup_dhcp` YaST client which does not need to remember any state.

## Supported URL Schemes

Currently only HTTP/HTTPS and FTP URL schemes are supported for downloading
the updates. Some additional schemes might work but are not tested and therefore
not supported.

## Error Handling

Errors during the installer update are handled as described below:

* If network is not available, the installer update will be skipped.
* If the network is configured but the installer updates repository or the
  registration server are not reachable:
  * in a regular installation/upgrade, YaST2 will offer the possibility
    to check/adjust the network configuration.
  * in an AutoYaST installation/upgrade, a warning will be shown.
* If SCC/SMT is used and it returns no URL or fails then the fallback URL from
  `control.xml` is used.
* If the updates repository is found but it is empty or not valid:
  * if the installer update was enabled explicitly (using the *SelfUpdate* boot
    option or through the *self_update* element in an AutoYaST profile), an error
    will be shown.
  * in the case that the URL was specified by the user (using the *SelfUpdate* boot
    option or through the *self_update_url* element in an AutoYaST profile), an
    error message will be shown.
  * if the URL was not specified by the user, the installer will skip the update
    process (it will assume that no updates are available).
* If something goes wrong trying to fetch and apply the update, the user will be
  notified.
