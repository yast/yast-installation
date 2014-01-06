module Yast
  import "UI"
  import "Label"

  #helper module to make proposal value persistent
  module CloneProposalHolder

    def self.value=(val)
      @@value = val
    end

    def self.value
      @@value = nil unless defined? @@value
      @@value
    end
  end

  class CloneProposalClient < Client
    CLONE_ENABLE_LINK = "clone_enable"
    CLONE_DISABLE_LINK = "clone_disable"

    def main
      textdomain "installation"

      Yast.import "Installation"
      Yast.import "ProductFeatures"

      func = WFM.Args(0)
      param = WFM.Args(1)

      product_clone_active = ProductFeatures.GetBooleanFeature(
        "globals",
        "enable_clone"
      )
      if CloneProposalHolder.value.nil?
        y2milestone("Set default value for cloning")
        CloneProposalHolder.value = product_clone_active
      end

      case func
      when "MakeProposal"
        CloneProposalHolder.value = product_clone_active if param["force_reset"]

        ret = {
          "preformatted_proposal" => proposal_text,
          "links"                 => [CLONE_ENABLE_LINK, CLONE_DISABLE_LINK],
          # TRANSLATORS: help text
          "help"                  => _(
            "<p><b>Clone System Settings</b> generates on target system in root" +
            " home autoyast profile that can automatic reproduce installation.</p>"
          )
        }
      when "AskUser"
        chosen_id = Ops.get(param, "chosen_id")
        Builtins.y2milestone(
          "Images proposal change requested, id %1",
          chosen_id
        )

        case chosen_id
        when CLONE_DISABLE_LINK
          CloneProposalHolder.value = false
        when CLONE_ENABLE_LINK
          CloneProposalHolder.value = true
        when "clone"
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
          "menu_title"      => _(
            "&Clone System Configuration"
          ),
          "id"              => "clone"
        }
      when "Write"
        WFM.call "clone_system" if CloneProposalHolder.value
        ret = true
      else
        raise "Unsuported action #{func}"
      end

      return ret
    end

    def proposal_text
      ret = "<ul><li>\n"

      if CloneProposalHolder.value
        ret << Builtins.sformat(
              # TRANSLATORS: Installation overview
              # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
              _(
                "Autoyast profile will be written under /root (<a href=\"%1\">do not write it</a>)."
              ),
              CLONE_DISABLE_LINK
            )
      else
        ret << Builtins.sformat(
              # TRANSLATORS: Installation overview
              # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
              _(
                "Autoyast profile won't be written under /root (<a href=\"%1\">write it</a>)."
              ),
              CLONE_ENABLE_LINK
            )
      end

      ret << "</li></ul>\n"
    end

    def clone_dialog
      dialog = VBox(
        CheckBox(Id(:value_holder), _("Write AutoYaST profile to /root"),
          CloneProposalHolder.value
        ),
        PushButton(Id(:ok), Label.OKButton)
      )

      UI.OpenDialog dialog
      UI.UserInput
      CloneProposalHolder.value = UI.QueryWidget(:value_holder, :Value)
      UI.CloseDialog
    end
  end
end

Yast::CloneProposalClient.new.main
