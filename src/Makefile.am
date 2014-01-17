# Sources for installation

module_DATA = \
  modules/ImageInstallation.rb \
  modules/InstData.rb \
  modules/InstFunctions.rb \
  modules/Vendor.rb \
  modules/SystemFilesCopy.rb

client_DATA = \
  clients/clone_proposal.rb \
  clients/clone_finish.rb \
  clients/copy_files_finish.rb \
  clients/copy_logs_finish.rb \
  clients/copy_systemfiles_finish.rb \
  clients/deploy_image_auto.rb \
  clients/deploying_proposal.rb \
  clients/desktop_finish.rb \
  clients/disintegrate_all_extensions.rb \
  clients/driver_update1_finish.rb \
  clients/driver_update2_finish.rb \
  clients/inst_addon_update_sources.rb \
  clients/installation.rb \
  clients/installation_settings_finish.rb \
  clients/inst_ask_online_update.rb \
  clients/inst_complex_welcome.rb \
  clients/inst_congratulate.rb \
  clients/inst_deploy_image.rb \
  clients/inst_disks_activate.rb \
  clients/inst_doit.rb \
  clients/inst_extrasources.rb \
  clients/inst_features.rb \
  clients/inst_finish.rb \
  clients/inst_check_autoinst_mode.rb \
  clients/inst_info.rb \
  clients/inst_initialization.rb \
  clients/inst_installation_options.rb \
  clients/inst_license.rb \
  clients/inst_network_check.rb \
  clients/inst_network_setup.rb \
  clients/inst_new_desktop.rb \
  clients/inst_pre_install.rb \
  clients/inst_prepare_image.rb \
  clients/inst_prepareprogress.rb \
  clients/inst_proposal.rb \
  clients/inst_release_notes.rb \
  clients/inst_restore_settings.rb \
  clients/inst_rpmcopy_secondstage.rb \
  clients/inst_save_hardware_status.rb \
  clients/inst_scc.rb \
  clients/inst_scenarios.rb \
  clients/inst_system_analysis.rb \
  clients/inst_upgrade_urls.rb \
  clients/inst_welcome.rb \
  clients/inst_worker_continue.rb \
  clients/inst_worker_initial.rb \
  clients/kernel_finish.rb \
  clients/ldconfig_finish.rb \
  clients/network_finish.rb \
  clients/pre_umount_finish.rb \
  clients/proxy_finish.rb \
  clients/random_finish.rb \
  clients/release_notes_popup.rb \
  clients/save_config_finish.rb \
  clients/save_hw_status_finish.rb \
  clients/ssh_service_finish.rb \
  clients/ssh_settings_finish.rb \
  clients/stroj-casu.rb \
  clients/switch_scr_finish.rb \
  clients/test_inst_client.rb \
  clients/test_proposal.rb \
  clients/umount_finish.rb \
  clients/update_wizard_steps.rb \
  clients/x11_finish.rb \
  clients/yast_inf_finish.rb

yncludedir = @yncludedir@/installation
ynclude_DATA = \
  include/installation/inst_inc_second.rb \
  include/installation/inst_inc_first.rb \
  include/installation/misc.rb \
  include/installation/inst_inc_all.rb

scrconf_DATA = \
  scrconf/cfg_boot.scr \
  scrconf/cfg_windowmanager.scr \
  scrconf/proc_modules.scr \
  scrconf/cfg_fam.scr \
  scrconf/etc_install_inf_options.scr \
  scrconf/etc_passwd.scr \
  scrconf/etc_install_inf_alias.scr \
  scrconf/etc_install_inf.scr \
  scrconf/run_df.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/deploy_image.rnc

desktop_DATA = \
  desktop/release_notes.desktop

fillup_DATA = \
  fillup/sysconfig.security-checksig

ylibdir = "${yast2dir}/lib/installation"
ylib_DATA = \
  lib/installation/clone_settings.rb


EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(desktop_DATA) $(fillup_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common
