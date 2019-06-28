# File:     src/lib/installation/clients/inst_save_y2logs.rb
# Module:  Installation
# Summary: Saving y2logs by calling save_y2logs
#

module Yast
  class SaveY2logs < Client
    def main
      Yast.import "Directory"
      Yast.import "Installation"
      Yast.import "ProductFeatures"

      if ProductFeatures.GetBooleanFeature("globals", "save_y2logs")
        target_path = ::File.join(
          Yast::Installation.destdir,
          Yast::Directory.logdir
        )

        # use the target /tmp when available to save memory
        target_tmp = File.join(Yast::Installation.destdir, "tmp")
        tmpdir = File.exist?(target_tmp) ? target_tmp : "/tmp"

        WFM.Execute(Yast::Path.new(".local.bash"),
          # set TMPDIR for `mktemp -d` so it uses the target disk, not inst-sys RAM disk
          # https://github.com/yast/yast-yast2/blob/482eecb6064e2a904864fdab17e8c4bed41065ff/scripts/save_y2logs#L72
          "TMPDIR=#{tmpdir} /usr/sbin/save_y2logs '#{target_path}/yast-installation-logs.tar.xz'")
      end
    end
  end
end
