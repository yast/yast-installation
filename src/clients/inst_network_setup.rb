# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
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
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
module Yast
  class InstNetworkSetupClient < Client
    def main
      Yast.import "UI"
      #
      # Authors:	Lukas Ocilka <locilka@suse.cz>
      #
      # Purpose:	This script allows to setup network in first
      #		stage of installation.
      #
      # See More:	FATE #301967
      #
      # $Id$
      #

      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "String"
      Yast.import "GetInstArgs"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Netmask"
      Yast.import "NetworkService"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Hostname"
      Yast.import "Sequencer"
      Yast.import "Progress"
      Yast.import "FileUtils"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Proxy"
      Yast.import "Linuxrc"
      Yast.import "Internet"

      # Variables -->

      @default_ret = GetInstArgs.going_back ? :back : :next

      @enable_back = GetInstArgs.enable_back
      @enable_next = GetInstArgs.enable_next

      @enable_back_in_netsetup = true

      # Currently probed network cards
      @lan_cards = nil

      # Currently available network cards prepared for table representation
      @table_items = []

      # Flag that network configuration is not needed
      @some_card_has_ip = false

      # Map of maps for each network device $["eth0" : $["interface_name":"HTML Summary"]]
      # containing the hardware information.
      @hardware_information = {}

      # Netork setting used in Write function
      @network_settings = {}
      @default_network_settings = { "setup_type" => "dhcp" }

      # <-- Functions

      # Script itself -->

      Wizard.CreateDialog

      ProbeAndGetNetworkCards()

      if @table_items == nil || Builtins.size(@table_items) == 0
        Builtins.y2milestone("No network cards found")
        return @default_ret
      end

      @aliases = {
        "netcard"  => lambda { NetworkCardDialog() },
        "netsetup" => lambda { NetworkSetupDialog() },
        "write"    => lambda { WriteNetworkSetupDialog() }
      }

      @sequence = {
        "ws_start" => "netcard",
        "netcard"  => { :abort => :abort, :next => "netsetup" },
        "netsetup" => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      @ret = Sequencer.Run(@aliases, @sequence)

      Wizard.CloseDialog

      if @ret == :abort
        return :abort
      else
        return @default_ret
      end 

      # EOF
    end

    # <-- Variables

    # Functions -->

    def CreateRichTextHWSummary(device_map)
      ret = ""

      if Ops.get_string(device_map.value, "device", "") != ""
        ret = Ops.add(
          Ops.add(ret, ret != "" ? "<br>" : ""),
          # TRANSLATORS: hardware information - HTML summary text
          # %1 is replaced with a variable network_device
          Builtins.sformat(
            _("Network Device: %1"),
            Ops.get_string(device_map.value, "device", "")
          )
        )
      end

      ret = Ops.add(
        Ops.add(ret, ret != "" ? "<br>" : ""),
        # TRANSLATORS: hardware information - HTML summary text
        # %1 is replaced with "Wireless" or "Wired"
        # See #nt1 below
        Builtins.sformat(
          _("Network type: %1"),
          Ops.get_boolean(device_map.value, "wlan", false) == true ?
            # TRANSLATORS: Describes a "Network type"
            # see #nt1 above
            _("Wireless") :
            # TRANSLATORS: Describes a "Network type"
            # see #nt1 above
            _("Wired")
        )
      )

      if Ops.get_string(device_map.value, "model", "") != ""
        ret = Ops.add(
          Ops.add(ret, ret != "" ? "<br>" : ""),
          # TRANSLATORS: hardware information - HTML summary text
          # %1 is replaced with a variable device_model
          Builtins.sformat(
            _("Model: %1"),
            Ops.get_string(device_map.value, "model", "")
          )
        )
      end

      if Ops.get_string(device_map.value, ["resource", "hwaddr", 0, "addr"], "") != ""
        ret = Ops.add(
          Ops.add(ret, ret != "" ? "<br>" : ""),
          # TRANSLATORS: hardware information - HTML summary text
          # %1 is replaced with a variable mac_address
          Builtins.sformat(
            _("MAC Address: %1"),
            Ops.get_string(
              device_map.value,
              ["resource", "hwaddr", 0, "addr"],
              ""
            )
          )
        )
      end

      if Ops.get_string(device_map.value, "vendor", "") != ""
        ret = Ops.add(
          Ops.add(ret, ret != "" ? "<br>" : ""),
          # TRANSLATORS: hardware information - HTML summary text
          # %1 is replaced with a variable hardware_vendor
          Builtins.sformat(
            _("Hardware Vendor: %1"),
            Ops.get_string(device_map.value, "vendor", "")
          )
        )
      end

      device_name = Ops.get_string(device_map.value, "dev_name", "")
      if Ops.get(@hardware_information, [device_name, "link_status"]) != nil
        ret = Ops.add(
          Ops.add(ret, ret != "" ? "<br>" : ""),
          Builtins.sformat(
            # TRANSLATORS: hardware information - HTML summary text
            # %1 is either "Connected" or "Disconnected" (*1)
            _("Link is: %1"),
            Ops.get(@hardware_information, [device_name, "link_status"]) == "1" ?
              # TRANSLATORS: hardware information, see *1
              _("Connected") :
              # TRANSLATORS: hardware information, see *1
              _("Disconnected")
          )
        )
      end

      ret
    end

    def ReadProxySettingsFromSystem
      # Read proxy settings and adjust the default settings
      progress_orig = Progress.set(false)
      Proxy.Read
      Progress.set(progress_orig)

      default_proxy_settings = Proxy.Export

      log_settings = deep_copy(default_proxy_settings)
      if Ops.get_string(log_settings, "proxy_user", "") != ""
        Ops.set(log_settings, "proxy_user", "***hidden***")
      end
      if Ops.get_string(log_settings, "proxy_password", "") != ""
        Ops.set(log_settings, "proxy_password", "***hidden***")
      end
      Builtins.y2milestone("Default proxy settings: %1", log_settings)

      Ops.set(
        @default_network_settings,
        "use_proxy",
        Ops.get_boolean(default_proxy_settings, "enabled", false)
      )

      # Examle: "http://cache.example.com:3128/"
      http_proxy = Ops.get_string(default_proxy_settings, "http_proxy", "")
      if Builtins.regexpmatch(http_proxy, "/$")
        http_proxy = Builtins.regexpsub(http_proxy, "(.*)/$", "\\1")
      end
      if Builtins.regexpmatch(http_proxy, "^[hH][tT][tT][pP]:/+")
        http_proxy = Builtins.regexpsub(
          http_proxy,
          "^[hH][tT][tT][pP]:/+(.*)",
          "\\1"
        )
      end
      http_proxy_settings = Builtins.splitstring(http_proxy, ":")
      Builtins.y2milestone("Using proxy values: %1", http_proxy_settings)

      Ops.set(
        @default_network_settings,
        "proxy_server",
        Ops.get(http_proxy_settings, 0, "")
      )
      Ops.set(
        @default_network_settings,
        "proxy_port",
        Ops.get(http_proxy_settings, 1, "")
      )

      Ops.set(
        @default_network_settings,
        "proxy_user",
        Ops.get_string(default_proxy_settings, "proxy_user", "")
      )
      Ops.set(
        @default_network_settings,
        "proxy_password",
        Ops.get_string(default_proxy_settings, "proxy_password", "")
      )

      nil
    end

    def ProbeAndGetNetworkCards
      Wizard.SetContents(
        # TRANSLATORS: dialog caption
        _("Network Setup Wizard: Probing Hardware..."),
        VBox(
          # TRANSLATORS: dialog busy message
          Label(_("Probing network cards..."))
        ),
        # TRANSLATORS: dialog help
        _("Network cards are being probed now."),
        false,
        false
      )
      Wizard.SetTitleIcon("yast-controller")

      @some_card_has_ip = false
      @lan_cards = Convert.convert(
        SCR.Read(path(".probe.netcard")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      @table_items = []

      Builtins.foreach(@lan_cards) do |one_netcard|
        Builtins.y2milestone("Found netcard: %1", one_netcard)
        card_name = Ops.get_locale(
          one_netcard,
          "model",
          Ops.get_locale(one_netcard, "device", _("Unknown Network Card"))
        )
        if Ops.greater_than(Builtins.size(card_name), 43)
          card_name = Ops.add(Builtins.substring(card_name, 0, 40), "...")
        end
        device_name = Ops.get_string(one_netcard, "dev_name")
        if device_name == nil
          Builtins.y2error(
            "Cannot obtain \"dev_name\" from %1. Netcard will not be used.",
            one_netcard
          )
          next
        end
        @table_items = Builtins.add(
          @table_items,
          Item(Id(device_name), card_name, device_name)
        )
        # empty map
        Ops.set(@hardware_information, device_name, {})
        # Link status
        if Ops.get(one_netcard, ["resource", "link", 0, "state"]) != nil
          Ops.set(
            @hardware_information,
            [device_name, "link_status"],
            Ops.get_boolean(
              one_netcard,
              ["resource", "link", 0, "state"],
              false
            ) ? "1" : "0"
          )
        end
        # hardware information later used in UI
        hwinfo_richtext = (
          one_netcard_ref = arg_ref(one_netcard);
          _CreateRichTextHWSummary_result = CreateRichTextHWSummary(
            one_netcard_ref
          );
          one_netcard = one_netcard_ref.value;
          _CreateRichTextHWSummary_result
        )
        if hwinfo_richtext != nil && hwinfo_richtext != ""
          Ops.set(
            @hardware_information,
            [device_name, "richtext"],
            hwinfo_richtext
          )
        end
        Ops.set(
          @hardware_information,
          [device_name, "module"],
          Ops.get_string(one_netcard, "driver_module", "")
        )
        Ops.set(
          @hardware_information,
          [device_name, "unique_key"],
          Ops.get_string(one_netcard, "unique_key", "")
        )
        Ops.set(
          @hardware_information,
          [device_name, "hward"],
          Ops.get_string(one_netcard, ["resource", "hwaddr", 0, "addr"], "")
        )
        Builtins.y2milestone(
          "Found network device: '%1' %2",
          device_name,
          card_name
        )
      end

      ReadProxySettingsFromSystem()

      # Use the default values
      if @network_settings == nil || @network_settings == {}
        @network_settings = deep_copy(@default_network_settings)
      end

      return :abort if Builtins.size(@table_items) == 0
      :next
    end

    def FillUpHardwareInformationWidget
      current_netcard = Convert.to_string(
        UI.QueryWidget(Id("netcard_selection"), :CurrentItem)
      )

      UI.ChangeWidget(
        Id("hardware_information"),
        # TRANSLATORS: hardware information widget content (a fallback)
        :Value,
        Ops.get(
          @hardware_information,
          [current_netcard, "richtext"],
          _("No additional information")
        )
      )

      nil
    end

    def MarkAlreadySelectedDevice
      # Pre-select the fist connected device
      # if no device is already selected
      if Ops.get(@network_settings, "network_device") == nil
        Builtins.foreach(@lan_cards) do |one_netcard|
          device_name = Ops.get_string(one_netcard, "dev_name", "")
          # First connected device
          if Ops.get(@hardware_information, [device_name, "link_status"], "X") == "1"
            UI.ChangeWidget(Id("netcard_selection"), :CurrentItem, device_name)
            raise Break
          end
        end

        return
      end

      UI.ChangeWidget(
        Id("netcard_selection"),
        :CurrentItem,
        Ops.get_string(@network_settings, "network_device", "")
      )

      nil
    end

    def CheckSelectedNetworkCard(selected_netcard)
      # Checking whether any netcard is selected
      if selected_netcard == nil || selected_netcard == ""
        # TRANSLATORS: pop-up error message
        Report.Error(
          _(
            "No network card has been selected.\n" +
              "\n" +
              "Select a network card to configure it later.\n"
          )
        )
        return false 

        # Checking whether the netcard link is active
      elsif Ops.get(@hardware_information, [selected_netcard, "link_status"]) == "0"
        if !Report.AnyQuestion(
            # TRANSLATORS: popup dialog caption
            _("Warning"),
            Builtins.sformat(
              # TRANSLATORS: popup dialog question
              # %1 is replaced with a network device string
              _(
                "The link of the selected interface %1 is disconnected.\n" +
                  "It needs to be connected for a proper network configuration.\n" +
                  "Are you sure you want to use it?"
              ),
              selected_netcard
            ),
            # TRANSLATORS: popup dialog button
            _("&Yes, Use it"),
            Label.NoButton,
            :no_button
          )
          Builtins.y2milestone(
            "User decided not to use disconnected '%1'",
            selected_netcard
          )
          return false
        else
          Builtins.y2warning(
            "User decided to use '%1' despite reported as inactive",
            selected_netcard
          )
        end
      end

      true
    end

    def NetworkCardDialog
      @enable_back_in_netsetup = true

      if Builtins.size(@table_items) == 1
        Ops.set(
          @network_settings,
          "network_device",
          Builtins.tostring(Ops.get_string(@table_items, [0, 0, 0], ""))
        )
        Builtins.y2milestone(
          "Only one network inteface, selecting %1",
          Ops.get(@network_settings, "network_device")
        )
        @enable_back_in_netsetup = false
        return :next
      end

      Wizard.SetContentsButtons(
        # TRANSLATORS: dialog caption
        _("Network Setup"),
        VBox(
          Left(Label(_("Select a network card to be configured."))),
          VWeight(
            3,
            Table(
              Id("netcard_selection"),
              Opt(:notify, :immediate),
              Header(_("Network Card"), _("Device")),
              @table_items
            )
          ),
          VSpacing(1),
          # TRANSLATORS: Rich text widget label
          Left(Label(_("Hardware Information of the Selected Network Card"))),
          VWeight(2, RichText(Id("hardware_information"), ""))
        ),
        # TRANSLATORS: dialog help 1/3
        _(
          "<p>Here you can configure your network cards to be used immediately.</p>"
        ) +
          # TRANSLATORS: dialog help 2/3
          _(
            "<p>If you do not need a network connection now,\nyou can safely skip the configuration.</p>"
          ) +
          # TRANSLATORS: dialog help 3/3
          _(
            "<p>To configure a network card, select it from the list\n" +
              "and click the <b>Next</b> button.\n" +
              "Otherwise, click <b>Cancel</b>.</p>\n"
          ),
        Label.BackButton,
        Label.NextButton
      )

      Wizard.DisableBackButton
      Wizard.EnableAbortButton
      Wizard.EnableNextButton

      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.SetTitleIcon("yast-controller")

      MarkAlreadySelectedDevice()
      FillUpHardwareInformationWidget()

      user_input = nil

      dialog_ret = :next

      while true
        user_input = UI.UserInput

        if user_input == "netcard_selection"
          FillUpHardwareInformationWidget()
          next
        elsif user_input == :next
          Ops.set(
            @network_settings,
            "network_device",
            Convert.to_string(
              UI.QueryWidget(Id("netcard_selection"), :CurrentItem)
            )
          )

          if !CheckSelectedNetworkCard(
              Ops.get_string(@network_settings, "network_device", "")
            )
            next
          end

          dialog_ret = :next
          break
        elsif user_input == :cancel
          dialog_ret = :abort
          break
        elsif user_input == :abort
          dialog_ret = :abort
          break
        elsif user_input == :back
          dialog_ret = :back
          break
        else
          Builtins.y2milestone("Uknown user input: %1", user_input)
        end
      end

      dialog_ret
    end

    def AdjustNetworkWidgets(default_button)
      UI.ChangeWidget(Id("network_type"), :CurrentButton, default_button)
      UI.ChangeWidget(
        Id("static_addr_frame"),
        :Enabled,
        default_button != "dhcp"
      )

      nil
    end

    def SetValidCharsForNetworkWidgets
      Builtins.foreach(["ip_address", "netmask", "gateway", "dns_server"]) do |id|
        UI.ChangeWidget(Id(id), :ValidChars, IP.ValidChars4)
      end

      nil
    end

    def ValidateStaticSetupSettings
      # ["ip_address", "netmask", "gateway", "dns_server"]

      ip_address = Convert.to_string(UI.QueryWidget(Id("ip_address"), :Value))
      if ip_address == "" || Builtins.regexpmatch(ip_address, "^[ \t\n]+$")
        UI.SetFocus(Id("ip_address"))
        # TRANSLATORS: error message
        Report.Error(_("IP address cannot be empty."))
        return false
      elsif !IP.Check4(ip_address) && !IP.Check6(ip_address)
        UI.SetFocus(Id("ip_address"))
        Report.Error(
          Ops.add(
            Ops.add(
              Builtins.sformat(
                # TRANSLATORS: Error message, %1 is replaced with invalid IP address
                _("'%1' is an invalid IP address."),
                ip_address
              ),
              "\n\n"
            ),
            IP.Valid4
          )
        )
        return false
      end

      netmask = Convert.to_string(UI.QueryWidget(Id("netmask"), :Value))
      if netmask == "" || Builtins.regexpmatch(netmask, "^[ \t\n]+$")
        UI.SetFocus(Id("netmask"))
        # TRANSLATORS: error message
        Report.Error(_("Netmask cannot be empty."))
        return false
      elsif !Netmask.Check4(netmask)
        UI.SetFocus(Id("netmask"))
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: Error message, %1 is replaced with invalid netmask
            _("'%1' is an invalid netmask."),
            netmask
          )
        )
        return false
      end

      gateway = Convert.to_string(UI.QueryWidget(Id("gateway"), :Value))
      if gateway == "" || Builtins.regexpmatch(gateway, "^[ \t\n]+$")
        UI.SetFocus(Id("gateway"))
        # TRANSLATORS: error message
        Report.Error(_("Gateway IP address cannot be empty."))
        return false
      elsif !IP.Check4(gateway) && !IP.Check6(gateway)
        UI.SetFocus(Id("gateway"))
        Report.Error(
          Ops.add(
            Ops.add(
              Builtins.sformat(
                # TRANSLATORS: Error message, %1 is replaced with invalid IP address
                _("'%1' is an invalid IP address of the gateway."),
                gateway
              ),
              "\n\n"
            ),
            IP.Valid4
          )
        )
        return false
      end

      dns_server = Convert.to_string(UI.QueryWidget(Id("dns_server"), :Value))
      if dns_server == "" || Builtins.regexpmatch(dns_server, "^[ \t\n]+$")
        UI.SetFocus(Id("dns_server"))
        # TRANSLATORS: error message
        Report.Error(_("DNS server IP address cannot be empty."))
        return false
      elsif !IP.Check4(dns_server) && !IP.Check6(dns_server)
        UI.SetFocus(Id("dns_server"))
        Report.Error(
          Ops.add(
            Ops.add(
              Builtins.sformat(
                # TRANSLATORS: Error message, %1 is replaced with invalid IP address
                _("'%1' is an invalid IP address of the DNS server."),
                dns_server
              ),
              "\n\n"
            ),
            IP.Valid4
          )
        )
        return false
      end

      true
    end

    def GetProxyServerFromURL(proxy_server)
      Builtins.y2milestone("Entered proxy server: %1", proxy_server)

      if Builtins.regexpmatch(proxy_server, ".*[hH][tT][tT][pP]://")
        proxy_server = Builtins.regexpsub(
          proxy_server,
          ".*[hH][tT][tT][pP]://(.*)",
          "\\1"
        )
      end

      if Builtins.regexpmatch(proxy_server, "/+$")
        proxy_server = Builtins.regexpsub(proxy_server, "(.*)/+", "\\1")
      end

      Builtins.y2milestone("Tested proxy server: %1", proxy_server)

      proxy_server
    end

    def ValidateProxySettings
      # ["proxy_server", "proxy_port"]

      proxy_server = Convert.to_string(
        UI.QueryWidget(Id("proxy_server"), :Value)
      )
      proxy_server = GetProxyServerFromURL(proxy_server)

      if proxy_server == "" || Builtins.regexpmatch(proxy_server, "^[ \t\n]+$")
        UI.SetFocus(Id("proxy_server"))
        # TRANSLATORS: error message
        Report.Error(_("Proxy server name or IP address must be set."))
        return false
      elsif !IP.Check4(proxy_server) && !IP.Check6(proxy_server) &&
          !Hostname.CheckFQ(proxy_server)
        UI.SetFocus(Id("proxy_server"))
        Report.Error(
          Ops.add(
            Ops.add(
              Builtins.sformat(
                # TRANSLATORS: Error message, %1 is replaced with invalid IP address
                _(
                  "'%1' is an invalid IP address or invalid hostname\nof a proxy server."
                ),
                proxy_server
              ),
              "\n\n"
            ),
            IP.Valid4
          )
        )
        return false
      end

      proxy_port = Convert.to_string(UI.QueryWidget(Id("proxy_port"), :Value))

      # empty
      if proxy_port == "" || Builtins.regexpmatch(proxy_port, "^[ \t\n]+$")
        UI.SetFocus(Id("proxy_port"))
        # TRANSLATORS: error message
        Report.Error(_("Proxy port must be set."))
        return false 
        # not matching 'number' format
      elsif !Builtins.regexpmatch(proxy_port, "^[0123456789]+$")
        UI.SetFocus(Id("proxy_port"))
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: Error message, %1 is replaced with invalid IP address
            _(
              "'%1' is an invalid proxy port number.\n" +
                "\n" +
                "Port number must be between 1 and 65535 inclusive."
            ),
            proxy_port
          )
        )
        return false 
        # a number
      else
        port_nr = Builtins.tointeger(proxy_port)

        # but wrong number
        if Ops.less_than(port_nr, 1) || Ops.greater_than(port_nr, 65535)
          UI.SetFocus(Id("proxy_port"))
          Report.Error(
            Builtins.sformat(
              # TRANSLATORS: Error message, %1 is replaced with invalid IP address
              _(
                "'%1' is an invalid proxy port number.\n" +
                  "\n" +
                  "Port number must be between 1 and 65535 inclusive."
              ),
              proxy_port
            )
          )
          return false
        end
      end


      true
    end

    def ValidateNetworkSettings
      # only static setup needs to check these settings
      network_setup_type = Convert.to_string(
        UI.QueryWidget(Id("network_type"), :CurrentButton)
      )
      if network_setup_type == "static" && !ValidateStaticSetupSettings()
        return false
      end

      use_proxy = Convert.to_boolean(UI.QueryWidget(Id("use_proxy"), :Value))
      return false if use_proxy && !ValidateProxySettings()

      true
    end

    def StoreNetworkSettingsMap
      # Network settings
      network_setup_type = Convert.to_string(
        UI.QueryWidget(Id("network_type"), :CurrentButton)
      )

      if network_setup_type == "static"
        Ops.set(@network_settings, "setup_type", "static")
      elsif network_setup_type == "dhcp"
        Ops.set(@network_settings, "setup_type", "dhcp")
      else
        Builtins.y2error("Unknown network setup '%1'", network_setup_type)
      end

      Builtins.foreach(["ip_address", "netmask", "gateway", "dns_server"]) do |widget_id|
        Ops.set(
          @network_settings,
          widget_id,
          Convert.to_string(UI.QueryWidget(Id(widget_id), :Value))
        )
      end

      # Proxy settings
      use_proxy = Convert.to_boolean(UI.QueryWidget(Id("use_proxy"), :Value))

      if use_proxy
        Ops.set(@network_settings, "use_proxy", true)

        Builtins.foreach(
          ["proxy_server", "proxy_port", "proxy_user", "proxy_password"]
        ) do |widget_id|
          Ops.set(
            @network_settings,
            widget_id,
            Convert.to_string(UI.QueryWidget(Id(widget_id), :Value))
          )
        end

        Ops.set(
          @network_settings,
          "proxy_server",
          GetProxyServerFromURL(
            Ops.get_string(@network_settings, "proxy_server", "")
          )
        )
      end

      nil
    end

    def FillUpNetworkSettings
      AdjustNetworkWidgets(Ops.get_string(@network_settings, "setup_type", ""))

      Builtins.foreach(
        [
          "ip_address",
          "netmask",
          "gateway",
          "dns_server",
          "proxy_server",
          "proxy_port",
          "proxy_user",
          "proxy_password"
        ]
      ) do |widget_id|
        if Ops.get(@network_settings, widget_id) != nil
          UI.ChangeWidget(
            Id(widget_id),
            :Value,
            Ops.get_string(@network_settings, widget_id, "")
          )
        end
      end

      UI.ChangeWidget(
        Id("use_proxy"),
        :Value,
        Ops.get_boolean(@network_settings, "use_proxy", false) == true
      )

      nil
    end

    def NetworkSetupDialog
      # centered & aligned dialog
      # see bugzilla #295043
      netsetup_dialog = VBox(
        VStretch(),
        Left(
          Label(
            Builtins.sformat(
              # TRANSLATORS: dialog label, %1 is replaced with a selected network device name, e.g, eth3
              # See *2
              _("Select your network setup type for %1"),
              Ops.get_locale(
                # TRANSLATORS: a fallback card name for *2
                @network_settings,
                "network_device",
                _("Unknown Network Card")
              )
            )
          )
        ),
        RadioButtonGroup(
          Id("network_type"),
          VBox(
            Left(
              RadioButton(
                Id("dhcp"),
                Opt(:notify),
                _("Automatic Address Setup (via &DHCP)")
              )
            ),
            Left(
              RadioButton(
                Id("static"),
                Opt(:notify),
                _("&Static Address Setup")
              )
            )
          )
        ),
        VSpacing(1),
        Left(
          HBox(
            HSpacing(4),
            HSquash(
              Frame(
                Id("static_addr_frame"),
                _("Static Address Settings"),
                VBox(
                  Left(
                    HBox(
                      HSquash(
                        MinWidth(
                          15,
                          InputField(Id("ip_address"), _("&IP Address"))
                        )
                      ),
                      HSpacing(0.5),
                      HSquash(
                        MinWidth(15, InputField(Id("netmask"), _("Net&mask")))
                      )
                    )
                  ),
                  Left(
                    HBox(
                      HSquash(
                        MinWidth(
                          15,
                          InputField(Id("gateway"), _("Default &Gateway IP"))
                        )
                      ),
                      HSpacing(0.5),
                      HSquash(
                        MinWidth(
                          15,
                          InputField(Id("dns_server"), _("D&NS Server IP"))
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        VSpacing(2),
        VSquash(
          HBox(
            HSpacing(4),
            Left(
              CheckBoxFrame(
                Id("use_proxy"),
                _("&Use Proxy for Accessing the Internet"),
                false,
                VBox(
                  Left(
                    HBox(
                      HSquash(
                        MinWidth(
                          42,
                          InputField(
                            Id("proxy_server"),
                            _("&HTTP Proxy Server"),
                            "http://"
                          )
                        )
                      ),
                      HSpacing(0.5),
                      HSquash(
                        MinWidth(
                          6,
                          ComboBox(
                            Id("proxy_port"),
                            Opt(:editable),
                            _("&Port"),
                            ["", "3128", "8080"]
                          )
                        )
                      )
                    )
                  ),
                  Left(
                    HBox(
                      HSquash(
                        MinWidth(
                          14,
                          InputField(Id("proxy_user"), _("Us&er (optional)"))
                        )
                      ),
                      HSpacing(0.5),
                      HSquash(
                        MinWidth(
                          14,
                          Password(
                            Id("proxy_password"),
                            _("Pass&word (optional)")
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        VStretch()
      )

      Wizard.SetContentsButtons(
        # TRANSLATORS: dialog caption
        _("Network Setup"),
        HBox(HStretch(), netsetup_dialog, HStretch()),
        # TRANSLATORS: dialog help 1/2
        _(
          "<p><big><b>Network Setup</b></big>\n" +
            "<br>Configure your network card.\n" +
            "Select either DHCP or static setup. DHCP fits for most cases.\n" +
            "For details contact your Internet provider or your network\n" +
            "administrator.</p>\n"
        ) +
          # TRANSLATORS: dialog help 2/2
          _(
            "<p><big><b>Proxy</b></big>\n" +
              "<br>Proxy is a server-based cache for accessing the web.\n" +
              "In most cases, if you have a direct connection to the Internet,\n" +
              "you do not need to use one.</p>\n"
          ),
        Label.BackButton,
        Label.OKButton
      )

      if @enable_back_in_netsetup
        Wizard.EnableBackButton
      else
        Wizard.DisableBackButton
      end
      Wizard.EnableAbortButton
      Wizard.EnableNextButton

      Wizard.SetAbortButton(:cancel, Label.CancelButton)
      Wizard.SetTitleIcon("yast-network")

      SetValidCharsForNetworkWidgets()

      # use the default settings when not yet set
      if @network_settings == {} || @network_settings == nil
        @network_settings = deep_copy(@default_network_settings)
      end
      FillUpNetworkSettings()

      user_input = nil

      dialog_ret = :next

      while true
        user_input = UI.UserInput

        if user_input == :cancel
          dialog_ret = :abort
          break
        elsif user_input == :back
          dialog_ret = :back
          break
        elsif user_input == "dhcp"
          AdjustNetworkWidgets("dhcp")
        elsif user_input == "static"
          AdjustNetworkWidgets("static")
        elsif user_input == :next
          if ValidateNetworkSettings()
            dialog_ret = :next
            StoreNetworkSettingsMap()
            break
          end
        else
          Builtins.y2error("Unknown ret: %1", user_input)
        end
      end

      dialog_ret
    end

    def FlushAllIPSettings
      Builtins.foreach(@hardware_information) do |netdevice, hwi|
        cmd = Builtins.sformat("/sbin/ip address flush '%1'", netdevice)
        run_cmd = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone("Running %1 returned %2", cmd, run_cmd)
      end

      # Bugzilla #308577
      # All local dhcpcd clients are shut down
      Internet.ShutdownAllLocalDHCPClients

      true
    end

    def Action_AdjustDHCPNetworkSetup
      FlushAllIPSettings()

      cmd = Builtins.sformat(
        "/sbin/dhcpcd '%1'",
        String.Quote(Ops.get_string(@network_settings, "network_device", ""))
      )
      run_cmd = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))
      Builtins.y2milestone("Running %1 returned %2", cmd, run_cmd)

      return false if Ops.get_integer(run_cmd, "exit", -1) != 0

      true
    end

    def ReportMoreErrorInformationIfPossible(command, command_run, popup_headline)
      command_run = deep_copy(command_run)
      errors = ""

      if Ops.get_string(command_run, "stdout", "") != ""
        errors = Ops.add(
          Ops.add(errors != "" ? "\n" : "", errors),
          Ops.get_string(command_run, "stdout", "")
        )
      end

      if Ops.get_string(command_run, "stderr", "") != ""
        errors = Ops.add(
          Ops.add(errors != "" ? "\n" : "", errors),
          Ops.get_string(command_run, "stderr", "")
        )
      end

      if errors != ""
        Popup.LongText(
          # TRANSLATORS: error popup headline
          popup_headline,
          MinSize(
            65,
            7,
            RichText(
              Builtins.sformat(
                # TRANSLATORS: error popup content (HTML)
                # %1 is replaced with a bash command
                # %2 is replaced with (possibly multiline) error output of the command
                _(
                  "<p>Command: <tt>%1</tt> has failed.</p>\n" +
                    "<p>The output of the command was:\n" +
                    "<pre>%2</pre></p>"
                ),
                command,
                errors
              )
            )
          ),
          30,
          7
        )
      end

      nil
    end

    def Action_AdjustStaticNetworkSetup
      # ["ip_address", "netmask", "gateway", "dns_server"]

      network_device = Ops.get_string(@network_settings, "network_device", "")
      ip_address = Ops.get_string(@network_settings, "ip_address", "")
      netmask = Ops.get_string(@network_settings, "netmask", "")
      # convert "255.255.240.0" type to bits
      if !Builtins.regexpmatch(netmask, "^[0123456789]+$")
        netmask = Builtins.tostring(Netmask.ToBits(netmask))
      end
      default_gateway = Ops.get_string(@network_settings, "gateway", "")
      dns_server = Ops.get_string(@network_settings, "dns_server", "")

      # Wake up the link
      cmd = Builtins.sformat(
        "/sbin/ip link set '%1' up",
        String.Quote(network_device)
      )
      run_cmd = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Running %1 returned %2", cmd, run_cmd)
      if Ops.get_integer(run_cmd, "exit", -1) != 0
        # TRANSLATORS: popup hedline
        ReportMoreErrorInformationIfPossible(
          cmd,
          run_cmd,
          _("Setting up Network Failed")
        )
        return false
      end

      FlushAllIPSettings()

      # Set the IP
      cmd = Builtins.sformat(
        "/sbin/ip address add '%1/%2' brd + dev '%3'",
        String.Quote(ip_address),
        String.Quote(netmask),
        String.Quote(network_device)
      )
      run_cmd = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Running %1 returned %2", cmd, run_cmd)
      if Ops.get_integer(run_cmd, "exit", -1) != 0
        # TRANSLATORS: popup headline
        ReportMoreErrorInformationIfPossible(
          cmd,
          run_cmd,
          _("Setting up Network Failed")
        )
        return false
      end

      # Set the default gateway
      cmd = Builtins.sformat(
        "/sbin/ip route add default via '%1'",
        String.Quote(default_gateway)
      )
      run_cmd = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Running %1 returned %2", cmd, run_cmd)
      if Ops.get_integer(run_cmd, "exit", -1) != 0
        # TRANSLATORS: popup headline
        ReportMoreErrorInformationIfPossible(
          cmd,
          run_cmd,
          _("Setting up Network Failed")
        )
        return false
      end

      # Write resolv conf
      if !Mode.normal
        resolv_file = "/etc/resolv.conf"
        resolv_conf = Builtins.sformat("nameserver %1\n", dns_server)

        success = SCR.Write(path(".target.string"), resolv_file, resolv_conf)

        if !success
          Builtins.y2error("Cannot write into %1 file", resolv_file)
          return false
        end
      end

      true
    end

    # Adjusts environment variables via new builtin 'setenv'
    def SetEnvironmentVariables(env_proxy_variables)
      env_proxy_variables = deep_copy(env_proxy_variables)
      #	map <string, any> env_proxy_variables = $[
      #	    "http_proxy"	: proxy_server,
      #	    "https_proxy"	: proxy_server,
      #	    "ftp_proxy"		: proxy_server,
      #	    "proxy_user"	: proxy_user,
      #	    "proxy_password"	: proxy_pass,
      #	];

      Builtins.setenv(
        "http_proxy",
        Ops.get_string(env_proxy_variables, "http_proxy", "")
      )
      Builtins.setenv(
        "HTTPS_PROXY",
        Ops.get_string(env_proxy_variables, "https_proxy", "")
      )
      Builtins.setenv(
        "FTP_PROXY",
        Ops.get_string(env_proxy_variables, "ftp_proxy", "")
      )
      Builtins.setenv("NO_PROXY", "localhost, 127.0.0.1")

      nil
    end

    def Action_ProxySetup
      tmp_sysconfig_dir = "/tmp/first_stage_network_setup/sysconfig/"
      sysconfig_file = "/etc/sysconfig/proxy"

      curlrc_file = "/root/.curlrc"
      if !FileUtils.Exists(curlrc_file)
        Builtins.y2milestone(
          "Creating file %1 returned: %2",
          curlrc_file,
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("touch '%1'", String.Quote(curlrc_file))
          )
        )
        # symlink the correct location of the conf-file
        # $HOME directory might be '/' in inst-sys
        Builtins.y2milestone(
          "Creating .curlrc symlink returned: %1",
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "ln --symbolic --force '%1' '/.curlrc'",
              String.Quote(curlrc_file)
            )
          )
        )
      end

      wgetrc_file = "/root/.wgetrc"
      if !FileUtils.Exists(wgetrc_file)
        Builtins.y2milestone(
          "Creating file %1 returned: %2",
          wgetrc_file,
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("touch '%1'", String.Quote(wgetrc_file))
          )
        )
        # symlink the correct location of the conf-file
        # $HOME directory might be '/' in inst-sys
        Builtins.y2milestone(
          "Creating .wgetrc symlink returned: %1",
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "ln --symbolic --force '%1' '/.wgetrc'",
              String.Quote(wgetrc_file)
            )
          )
        )
      end

      if Stage.initial
        # Flush the cache if needed
        # file will be changed
        SCR.Write(path(".sysconfig.proxy"), nil)
        SCR.Write(path(".root.curlrc"), nil)
        SCR.Write(path(".root.wgetrc"), nil)

        # Creates temporary directory
        # Cerates 'proxy' file there
        # Merges the 'proxy' file to the current inst-sys
        cmd = Builtins.sformat(
          "mkdir -p '%1' &&\n" +
            "touch '%1proxy' &&\n" +
            "/sbin/adddir '%1' '/etc/sysconfig/'",
          String.Quote(tmp_sysconfig_dir)
        )
        cmd_run = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        if Ops.get_integer(cmd_run, "exit", -1) != 0
          Builtins.y2error("Command %1 failed with %2", cmd, cmd_run)
          # TRANSLATORS: popup error message
          Report.Error(
            _(
              "A failure occurred during preparing\nthe installation system for writing the proxy configuration."
            )
          )
          return false
        end

        # File has been changed, reread proxy settings
        progress_orig2 = Progress.set(false)
        Proxy.Read
        Progress.set(progress_orig2)
      end

      proxy_server = Builtins.sformat(
        "http://%1:%2/",
        Ops.get_string(@network_settings, "proxy_server", ""),
        Ops.get_string(@network_settings, "proxy_port", "")
      )

      proxy_user = Ops.get_string(@network_settings, "proxy_user", "")
      proxy_pass = Ops.get_string(@network_settings, "proxy_password", "")

      import_proxy = {
        "http_proxy"     => proxy_server,
        "https_proxy"    => proxy_server,
        "ftp_proxy"      => proxy_server,
        "proxy_user"     => proxy_user,
        "proxy_password" => proxy_pass
      }

      if Ops.get(@network_settings, "use_proxy") == true
        Ops.set(import_proxy, "enabled", true)
      else
        Ops.set(import_proxy, "enabled", false)
      end
      Proxy.Import(import_proxy)

      progress_orig = Progress.set(false)
      Proxy.Write
      Progress.set(progress_orig)

      # Bugzilla #305163
      SetEnvironmentVariables(import_proxy)

      true
    end

    def WriteInstallInfEntry(inst_inf_entry, value)
      # Entry name must be set
      if inst_inf_entry == "" || inst_inf_entry == nil
        Builtins.y2error("No entry name defined")
        return false
      end

      # Value must be set
      if value == "" || value == nil
        Builtins.y2warning("Value for '%1' is '%2'", inst_inf_entry, value) 
        # Can contain username/passowrd
      else
        Builtins.y2debug("Writing %1=%2", inst_inf_entry, value)
      end

      SCR.Write(Builtins.add(path(".etc.install_inf"), inst_inf_entry), value)
    end

    # Writes network setings to the install.inf file.
    def Action_WriteInstallInf
      inf_filename = "/etc/install.inf"

      if !Stage.initial
        Builtins.y2milestone(
          "Not an inst-sys, skipping writing %1",
          inf_filename
        )
        return true
      end

      if !FileUtils.Exists(inf_filename)
        Builtins.y2error("File %1 is missing!", inf_filename)
        return false
      end

      # These variables are already present in the install.inf
      already_used_variables = SCR.Dir(path(".etc.install_inf"))

      network_variables = [
        "NetConfig",
        "IP",
        "Netmask",
        "Netdevice",
        "Gateway",
        "Nameserver",
        "HWAddr",
        "Alias",
        "NetUniqueID",
        "Broadcast",
        "Hostname"
      ]

      # Remove all network-related settings
      Builtins.foreach(network_variables) do |inf_var|
        if Builtins.contains(already_used_variables, inf_var)
          Builtins.y2milestone("Removing %1 from install.inf", inf_var)
          SCR.Write(Builtins.add(path(".etc.install_inf"), inf_var), nil)
        end
      end

      # Write settings into the install.inf
      netdevice = Ops.get_string(@network_settings, "network_device", "")
      WriteInstallInfEntry("Netdevice", netdevice)

      # DHCP setup type
      if Ops.get(@network_settings, "setup_type") == "dhcp"
        WriteInstallInfEntry("NetConfig", "dhcp") 

        # Static setup type
      elsif Ops.get(@network_settings, "setup_type") == "static"
        WriteInstallInfEntry("NetConfig", "static")
        WriteInstallInfEntry(
          "IP",
          Ops.get_string(@network_settings, "ip_address", "")
        )
        WriteInstallInfEntry(
          "Hostname",
          Ops.get_string(@network_settings, "ip_address", "")
        )

        netmask = Ops.get_string(@network_settings, "netmask", "")
        # If netmask is defined as a number of bits, convert it
        if Builtins.regexpmatch(netmask, "^[0123456789]+$")
          netmask = IP.ToString(Builtins.tointeger(netmask))
          Builtins.y2milestone(
            "Converted netmask from %1 to %2",
            Ops.get_string(@network_settings, "netmask", ""),
            netmask
          )
        end
        WriteInstallInfEntry("Netmask", netmask)


        WriteInstallInfEntry(
          "Broadcast",
          IP.ComputeBroadcast(
            Ops.get_string(@network_settings, "ip_address", ""),
            Ops.get_string(@network_settings, "netmask", "")
          )
        )
        WriteInstallInfEntry(
          "Gateway",
          Ops.get_string(@network_settings, "gateway", "")
        )
        WriteInstallInfEntry(
          "Nameserver",
          Ops.get_string(@network_settings, "dns_server", "")
        ) 

        # Unknown setup type
      else
        Builtins.y2error(
          "Unknown netsetup type %1, using 'dhcp'",
          Ops.get(@network_settings, "setup_type")
        )
        WriteInstallInfEntry("NetConfig", "dhcp")
      end

      # Write also hardware information
      WriteInstallInfEntry(
        "Alias",
        Ops.get(@hardware_information, [netdevice, "module"], "")
      )
      WriteInstallInfEntry(
        "NetUniqueID",
        Ops.get(@hardware_information, [netdevice, "unique_key"], "")
      )
      WriteInstallInfEntry(
        "HWAddr",
        Ops.get(@hardware_information, [netdevice, "hward"], "")
      )

      if Ops.get(@network_settings, "use_proxy") == true
        proxy_auth = ""

        if Ops.get_string(@network_settings, "proxy_user", "") != "" &&
            Ops.get_string(@network_settings, "proxy_password", "") != ""
          proxy_auth = Builtins.sformat(
            "%1:%2",
            # escaping ":"s in username
            Builtins.mergestring(
              Builtins.splitstring(
                Ops.get_string(@network_settings, "proxy_user", ""),
                ":"
              ),
              "\\:"
            ),
            # escaping ":"s in password
            Builtins.mergestring(
              Builtins.splitstring(
                Ops.get_string(@network_settings, "proxy_password", ""),
                ":"
              ),
              "\\:"
            )
          )
        end

        proxy_server = nil

        # no proxy auth
        if proxy_auth == ""
          proxy_server = Builtins.sformat(
            "http://%1:%2/",
            Ops.get_string(@network_settings, "proxy_server", ""),
            Ops.get_string(@network_settings, "proxy_port", "")
          ) 
          # write proxy auth as well
        else
          proxy_server = Builtins.sformat(
            "http://%1@%2:%3/",
            proxy_auth,
            Ops.get_string(@network_settings, "proxy_server", ""),
            Ops.get_string(@network_settings, "proxy_port", "")
          )
        end

        WriteInstallInfEntry("Proxy", proxy_server)
      else
        WriteInstallInfEntry("Proxy", nil)
      end

      # Flush the SCR agent cache to the disk
      SCR.Write(path(".etc.install_inf"), nil)

      # Reset cached install.inf
      Linuxrc.ResetInstallInf

      true
    end

    # Internet test failed but user might want to accept it
    # true -> skip
    # false -> do not skip
    def SkipFailedInetTest
      if Popup.AnyQuestion(
          # TRANSLATORS: a pop-up dialog headline
          _("Internet Test Failed"),
          # TRANSLATORS: a pop-up dialog question, see buttons *3
          _(
            "The Internet connection test failed. You should be\n" +
              "redirected to the previous dialog to change the configuration.\n" +
              "Go back and change it?"
          ),
          # TRANSLATORS: popup dialog button (*3)
          _("Go Back"),
          # TRANSLATORS: popup dialog button (*3)
          _("Skip"),
          :yes
        )
        return false
      end

      true
    end

    def LogDebugInformation
      Builtins.y2milestone("--- logging network settings ---")
      Builtins.foreach(
        [
          "/sbin/ip addr show",
          "/sbin/ip route show",
          "/bin/cat /etc/resolv.conf"
        ]
      ) do |one_command|
        Builtins.y2milestone(
          "Command: %1 returned %2",
          one_command,
          SCR.Execute(path(".target.bash_output"), one_command)
        )
      end
      Builtins.y2milestone("--- logging network settings ---")

      nil
    end

    # FIXME: should be unified with Network YaST module
    def Action_TestInternetConnection
      #	ping-based test removed on Coolo's request
      #	(in some networks, ping is denied by firewall)
      #
      #	// Test the DNS plus routing
      #	boolean ping_result = false;
      #	map cmd_failed = $[];
      #	string cmd_failed_cmd = "";
      #
      #	// Testing more addresses, at least one should succeed
      #	foreach (string one_address, ["novell.com", "www.opensuse.org", "www.suse.com"], {
      #	    string cmd = sformat ("/bin/ping -q -n -c1 '%1'", String::Quote (one_address));
      #	    map run_cmd = (map) SCR::Execute (.target.bash_output, cmd);
      #	    y2milestone ("Running %1 returned %2", cmd, run_cmd);
      #
      #	    // Comand failed
      #	    if (run_cmd["exit"]:-1 != 0) {
      #		// Store the last failed command output
      #		cmd_failed_cmd = cmd;
      #		cmd_failed = run_cmd;
      #	    // Success
      #	    } else {
      #		// A successfull ping means we do not need to test more of them
      #		ping_result = true;
      #		break;
      #	    }
      #	});
      #
      #	// All ping-commands failed
      #	if (ping_result != true) {
      #	    LogDebugInformation();
      #
      #	    // TRANSLATORS: popup headline
      #	    ReportMoreErrorInformationIfPossible (cmd_failed_cmd, cmd_failed, _("Internet Test Failed"));
      #
      #	    if (SkipFailedInetTest()) {
      #		y2warning ("Internet test failed, but skipping the rest on user's request...");
      #		return true;
      #	    }
      #
      #	    return false;
      #	}

      www_result = false
      www_failed = {}
      cmd_failed_www = ""

      Builtins.foreach(
        [
          "http://www.novell.com",
          "http://www.opensuse.org",
          "http://www.suse.com"
        ]
      ) do |www_address|
        cmd = Builtins.sformat(
          "curl --silent --show-error --max-time 45 --connect-timeout 30 '%1' 1>/dev/null",
          String.Quote(www_address)
        )
        run_cmd = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone("Running %1 returned %2", cmd, run_cmd)
        # Comand failed
        if Ops.get_integer(run_cmd, "exit", -1) != 0
          # Store the last failed command output
          www_failed = deep_copy(run_cmd)
          cmd_failed_www = cmd 
          # Success
        else
          # A successfull ping means we do not need to test more of them
          www_result = true
          raise Break
        end
      end

      # All curl-commands failed
      if www_result != true
        LogDebugInformation()

        # TRANSLATORS: popup headline
        ReportMoreErrorInformationIfPossible(
          cmd_failed_www,
          www_failed,
          _("Internet Test Failed")
        )

        if SkipFailedInetTest()
          Builtins.y2warning(
            "Internet test failed, but skipping the rest on user's request..."
          )
          return true
        end

        return false
      end

      true
    end

    def WriteNetworkSetupDialog
      # Example:
      # network_settings =~ $[
      #	"dns_server":"192.168.0.3",
      #	"gateway":"192.168.0.1",
      #	"ip_address":"192.168.1.100",
      #	"netmask":"255.255.255.0",
      #	"network_device":"eth2",
      #	"proxy_password":"pass",
      #	"proxy_port":"3128",
      #	"proxy_server":"cache.suse.cz",
      #	"proxy_user":"user",
      #	"setup_type":"static",
      #	"use_proxy":true
      # ]

      actions_todo = []
      actions_doing = []
      actions_functions = []
      visible_icons = []
      invisible_icons = []

      # Dynamic network setup
      if Ops.get_string(@network_settings, "setup_type", "") == "dhcp"
        # TRANSLATORS: progress step
        actions_todo = Builtins.add(
          actions_todo,
          _("Adjust automatic network setup (via DHCP)")
        )
        # TRANSLATORS: progress step
        actions_doing = Builtins.add(
          actions_doing,
          _("Adjusting automatic network setup (via DHCP)...")
        )
        actions_functions = Builtins.add(
          actions_functions,
          fun_ref(method(:Action_AdjustDHCPNetworkSetup), "boolean ()")
        )
        invisible_icons = Builtins.add(
          invisible_icons,
          "32x32/apps/yast-network.png"
        )
        visible_icons = Builtins.add(visible_icons, "32x32/apps/yast-dns.png") 

        # Static network setup
      elsif Ops.get_string(@network_settings, "setup_type", "") == "static"
        # TRANSLATORS: progress step
        actions_todo = Builtins.add(
          actions_todo,
          _("Adjust static network setup")
        )
        # TRANSLATORS: progress step
        actions_doing = Builtins.add(
          actions_doing,
          _("Adjusting static network setup...")
        )
        actions_functions = Builtins.add(
          actions_functions,
          fun_ref(method(:Action_AdjustStaticNetworkSetup), "boolean ()")
        )
        invisible_icons = Builtins.add(
          invisible_icons,
          "32x32/apps/yast-network.png"
        )
        visible_icons = Builtins.add(visible_icons, "32x32/apps/yast-dns.png") 

        # Error
      else
        Builtins.y2error(
          "Unknown network setup type: '%1'",
          Ops.get_string(@network_settings, "setup_type", "")
        )
        # TRANSLATORS: pop-up error message
        Report.Error(
          _(
            "Unknown network setup.\n" +
              "\n" +
              "Please, go back and provide a valid network setup."
          )
        )
        return :back
      end

      # Always write settings, might be already in use
      # and we might want to disable it
      # TRANSLATORS: progress step
      actions_todo = Builtins.add(actions_todo, _("Write proxy settings"))
      # TRANSLATORS: progress step
      actions_doing = Builtins.add(
        actions_doing,
        _("Writing proxy settings...")
      )
      actions_functions = Builtins.add(
        actions_functions,
        fun_ref(method(:Action_ProxySetup), "boolean ()")
      )
      invisible_icons = Builtins.add(
        invisible_icons,
        "32x32/apps/yast-network.png"
      )
      visible_icons = Builtins.add(visible_icons, "32x32/apps/yast-proxy.png")

      # Write install.inf only in inst-sys
      if Stage.initial
        # TRANSLATORS: progress step
        actions_todo = Builtins.add(
          actions_todo,
          _("Adjust installation system")
        )
        # TRANSLATORS: progress step
        actions_doing = Builtins.add(
          actions_doing,
          _("Adjusting installation system...")
        )
        actions_functions = Builtins.add(
          actions_functions,
          fun_ref(method(:Action_WriteInstallInf), "boolean ()")
        )
        invisible_icons = Builtins.add(
          invisible_icons,
          "32x32/apps/yast-network.png"
        )
        visible_icons = Builtins.add(visible_icons, "32x32/apps/yast.png")
      end

      # TRANSLATORS: progress step
      actions_todo = Builtins.add(actions_todo, _("Test Internet connection"))
      # TRANSLATORS: progress step
      actions_doing = Builtins.add(
        actions_doing,
        _("Testing Internet connection...")
      )
      actions_functions = Builtins.add(
        actions_functions,
        fun_ref(method(:Action_TestInternetConnection), "boolean ()")
      )
      invisible_icons = Builtins.add(
        invisible_icons,
        "32x32/apps/yast-network.png"
      )
      visible_icons = Builtins.add(visible_icons, "32x32/apps/yast-isns.png")

      Progress.NewProgressIcons(
        # TRANSLATORS: dialog caption
        _("Writing Network Setup..."),
        " ",
        Builtins.size(actions_todo),
        actions_todo,
        actions_doing,
        # TRANSLATORS: dialog help
        _(
          "<p>Please, wait while network configuration is being written and tested...</p>"
        ),
        [visible_icons, invisible_icons]
      )

      Wizard.SetBackButton(:back, Label.BackButton)
      Wizard.SetNextButton(:next, Label.NextButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.SetTitleIcon("yast-network")

      all_ok = true
      Builtins.foreach(actions_functions) do |run_function|
        Progress.NextStage
        Builtins.y2milestone("Running function: %1", run_function)
        run_this = Convert.convert(
          run_function,
          :from => "any",
          :to   => "boolean ()"
        )
        ret = run_this.call
        Builtins.y2milestone("Function %1 returned %2", run_function, ret)
        if ret != true
          all_ok = false
          raise Break
        end
      end

      # If writing failed, return `back
      if all_ok != true
        Builtins.y2warning(
          "Writing has failed, returning to the previous dialog"
        )
        Report.Error(
          _(
            "Writing the network settings failed.\n" +
              "You will be returned to the previous dialog to either\n" +
              "change the settings or cancel the network setup.\n"
          )
        )
        return :back
      end

      Progress.Finish
      Builtins.sleep(500)

      :next
    end
  end
end

Yast::InstNetworkSetupClient.new.main
