# ------------------------------------------------------------------------------
# Copyright (c) 2014 SUSE Linux GmbH. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
# ------------------------------------------------------------------------------
require "installation/remote_finish_client"

Installation::RemoteFinishClient.new.run(*Yast::WFM.Args)
