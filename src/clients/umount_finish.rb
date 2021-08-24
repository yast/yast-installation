require "yast"
require "installation/clients/umount_finish"

Installation::Clients::UmountFinishClient.run(*Yast::WFM.Args)
