# a quick test of dialog layout without running the whole installation business
require "yast"
require "installation/select_system_role"

Yast.import "ProductControl"
Yast.import "Wizard"

Yast::ProductControl.custom_control_file =
  ENV["HOME"] + "/binaries/y2update/control.xml"
Yast::ProductControl.Init

Yast::Wizard.OpenLeftTitleNextBackDialog()

::Installation::SelectSystemRole.new.run
