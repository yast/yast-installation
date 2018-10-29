# encoding: utf-8
# File:	   src/lib/installation/clients/inst_save_y2logs.rb
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
              Yast::Directory.logdir)

         WFM.Execute(Yast::Path.new(".local.bash"),
           "/usr/sbin/save_y2logs '#{target_path}/yast-installation-logs.tar.xz'")
      end
    end
  end  
end
