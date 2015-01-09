require "installation/clone_settings"

module Yast
  import "UI"
  import "Label"

  class CloneProposalClient < Client
    CLONE_ENABLE_LINK = "clone_enable"
    CLONE_DISABLE_LINK = "clone_disable"
    CLONE_ACTION_ID = "clone"

    def main
      textdomain "installation"

      @clone_settings = ::Installation::CloneSettings.instance
      Yast.import "Installation"
      Yast.import "ProductFeatures"

      func = WFM.Args[0]
      param = WFM.Args[1] || {}

      product_clone_active = ProductFeatures.GetBooleanFeature(
        "globals",
        "enable_clone"
      )
      if @clone_settings.enabled.nil?
        y2milestone("Set default value for cloning")
        @clone_settings.enabled = product_clone_active
      end

      case func
      when "MakeProposal"
        @clone_settings.enabled = product_clone_active if param["force_reset"]

        ret = {
          "preformatted_proposal" => proposal_text,
          "links"                 => [CLONE_ENABLE_LINK, CLONE_DISABLE_LINK],
          # TRANSLATORS: help text
          "help"                  => _(
            "<p>Use <b>Clone System Settings</b> if you want to create an AutoYaST profile.\n" +
              "AutoYaST is a way to do a complete SUSE Linux installation without user interaction. AutoYaST\n" +
              "needs a profile to know what the installed system should look like. If this option is\n" +
              "selected, a profile of the current system is stored in <tt>/root/autoinst.xml</tt>.</p>"
          )
        }
      when "AskUser"
        chosen_id = Ops.get(param, "chosen_id")
        Builtins.y2milestone(
          "Clone proposal change requested, id %1",
          chosen_id
        )

        case chosen_id
        when CLONE_DISABLE_LINK
          @clone_settings.enabled = false
        when CLONE_ENABLE_LINK
          @clone_settings.enabled = true
        when CLONE_ACTION_ID
          clone_dialog
        else
          raise "Unexpected value #{chosen_id}"
        end

        ret = { "workflow_sequence" => :next }
      when "Description"
        ret = {
          # this is a heading
          "rich_text_title" => _("Clone System Configuration"),
          # this is a menu entry
          "menu_title"      => _("&Clone System Configuration"),
          "id"              => CLONE_ACTION_ID
        }
      when "Write"
        if param["force"] || @clone_settings.enabled?
          # keep mode, cloning set it to autoinst_config, but we need to continue
          # installation with original one(BNC#861520)
          options = {}
          options["target_path"] = param["target_path"] if param["target_path"]
          mode = Mode.mode
          WFM.call("clone_system",[options])
          Mode.SetMode(mode)
        end
        ret = true
      else
        raise "Unsuported action #{func}"
      end

      return ret
    end

    def proposal_text
      ret = "<ul><li>\n"

      if @clone_settings.enabled?
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "The AutoYaST profile will be written under /root/autoinst.xml (<a href=\"%1\">do not write it</a>)."
          ),
          CLONE_DISABLE_LINK
        )
      else
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "The AutoYaST profile will not be saved (<a href=\"%1\">write it</a>)."
          ),
          CLONE_ENABLE_LINK
        )
      end

      ret << "</li></ul>\n"
    end

    def clone_dialog
      dialog = VBox(
        CheckBox(Id(:value_holder), _("Write AutoYaST profile to /root/autoinst.xml"),
          @clone_settings.enabled?
        ),
        PushButton(Id(:ok), Label.OKButton)
      )

      UI.OpenDialog dialog
      UI.UserInput
      @clone_settings.enabled = UI.QueryWidget(:value_holder, :Value)
      UI.CloseDialog
    end
  end unless defined? (CloneProposalClient) # avoid class redefinition if reevaluated
end

Yast::CloneProposalClient.new.main
