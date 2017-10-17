# System Upgrade

## Introduction

With the **system upgrade** term we mean upgrading the installed system to a new
product version.

### Note

The offline/online term refers to the system state, it is not about network status
or about using remote (HTTP/FTP/...) or local (DVD/disk/...) installation
repositories.

At the online upgrade the system is running and the packages are upgraded while
the system is in use. At the offline upgrade the system is rebooted into
installation medium and the system cannot be used during the upgrade.

The online upgrade can used for a service pack level upgrade, for upgrading to
a new product version the offline upgrade should be used.

### Recommendations

- It is recommended to install all latest online updates before running the
  upgrade. The updates might include a fix for the system upgrade.

- In all cases it is recommended to backup the old system before doing
  an upgrade.


## Related Features

- [FATE#323163](https://fate.suse.com/323163) - YaST: SLES12 to SLES15 migration

## SLE-15 Offline Upgrade Workflow

The high level upgrade workflow should include these steps:

1. Start the installer
1. Select the language/keyboard
1. Select the root partition with the system to upgrade
1. Display and confirm the license of the new system
1. Load the installed products (the base product and all add-ons)
1. Load the matching base product from the medium
1. Send the the installed products and the product from medium to SCC/SMT
1. The response will contain the possible upgrades, some add-ons might be
   available in multiple versions, user should be able to select which version
   will be installed
1. Ask the SCC/SMT to upgrade the registration to the selected versions,
   this will add new installation repositories with packages to upgrade
1. Switch libzypp into the distribution upgrade mode and run the package solver
   to select the needed packages for upgrade
1. Display the upgrade summary, until this point it is still possible to abort
   the upgrade and revert the system back into the original system.
1. After user confirms the upgrade YaST starts the package installation.
   After the package upgrade starts it is possible to restore the original
   system only from a snapshot (if enabled in the system) or from a backup.
1. Run the finish clients to adjust the system configuration
1. Reboot into the upgraded system

#### Notes

- SCC/SMT will always add all available modules to make sure all SLE12 packages
  can be upgraded to their SLE15 version
- The system will be upgraded only to the version available on the installation
  medium. In theory we could upgrade even to a newer version (SP+1), but to
  limit the QA and the testing scope it is limited only to the base product on
  the medium.


#### Not Registered System

If the system is not registered then steps 4. to 9. are skipped and the user
can use the provided DVD media for the upgrade. If upgrade via SCC/SMT is still
required the system should be rebooted into the old system and registered there.


#### The Old Medium Based Upgrade

This is basically the same as the upgrade of an unregistered system described
above but can be manually forced even for a registered system. The switch
will be done via a hidden boot parameter (not displayed in the isolinux boot
menu). **(Not implemented yet)**


