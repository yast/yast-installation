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

require "yast"

require "installation/proposal_store"

module Installation
  # Create and display reasonable proposal for basic
  # installation and call sub-workflows as required
  # on user request.
  #
  # See {Installation::ProposalClient} from yast2 for API overview
  class ProposalRunner
    include Yast::I18n
    include Yast::UIShortcuts
    include Yast::Logger

    def self.run
      new.run
    end

    def initialize(store = ::Installation::ProposalStore)
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "AutoinstConfig"
      Yast.import "Wizard"
      Yast.import "HTML"
      Yast.import "Popup"
      Yast.import "Language"
      Yast.import "GetInstArgs"
      Yast.import "ProductControl"
      Yast.import "HTML"

      # values used in defined functions

      @submodules_presentation = []
      @mod2tab = {} # module -> tab it is in
      @current_tab = 0 # ID of current tab
      @html = {} # proposals of all modules - HTML part
      @have_blocker = false

      # BNC #463567
      @submods_already_called = []
      @store_class = store
    end

    def run
      # skip if not interactive mode.
      if !Yast::AutoinstConfig.Confirm && (Yast::Mode.autoinst || Yast::Mode.autoupgrade)
        return :auto
      end

      args = (Yast::WFM.Args || []).first || {}
      @hide_export = args["hide_export"]

      log.info "Installation step #2"
      @proposal_mode = Yast::GetInstArgs.proposal

      if Yast::ProductControl.GetDisabledProposals.include?(@proposal_mode)
        return :auto
      end

      @store = @store_class.new(@proposal_mode)

      build_dialog

      #
      # Get submodule descriptions
      #
      proposal_result = load_matching_submodules_list
      return :abort if proposal_result == :abort

      Yast::UI.ChangeWidget(Id(:menu_dummy), :Enabled, false) if Yast::UI.TextMode
      richtext_busy_cursor(Id(:proposal))

      # The "next" button is disabled via Wizard::SetContents() until everything is set up allright
      Yast::Wizard.EnableNextButton
      Yast::Wizard.EnableAbortButton

      return :auto if !submod_descriptions_and_build_menu

      #
      # Make the initial proposal
      #
      make_proposal(false, false)

      # Set keyboard focus to the [Install] / [Update] or [Next] button
      Yast::Wizard.SetFocusToNextButton

      input_loop
    end

  private

    # Shows dialog to user to confirm update and return user response.
    # Returns 'true' if the user confirms, 'false' otherwise.
    #
    def confirm_update
      # Heading for confirmation popup before the update really starts
      heading = Yast::HTML.Heading(_("Confirm Update"))

      body =
        # Text for confirmation popup before the update really starts 1/3
        _("<p>Information required to perform an update is now complete.</p>") +
          # Text for confirmation popup before the update really starts 2/3
          _(
            "\n" \
            "<p>If you continue now, data on your hard disk will be overwritten\n" \
            "according to the settings in the previous dialogs.</p>"
          ) +
          # Text for confirmation popup before the update really starts 3/3
          _("<p>Go back and check the settings if you are unsure.</p>")

      # Label for the button that confirms startint the installation
      confirm_button_label = _("Start &Update")

      size_x = 70
      size_y = 18

      Yast::UI.OpenDialog(
        VBox(
          VSpacing(0.4),
          HSpacing(size_x), # force width
          HBox(
            HSpacing(0.7),
            VSpacing(size_y), # force height
            RichText(heading + body),
            HSpacing(0.7)
          ),
          ButtonBox(
            PushButton(
              Id(:cancel),
              Opt(:cancelButton, :key_F10, :default),
              Yast::Label.BackButton
            ),
            PushButton(Id(:ok), Opt(:okButton, :key_F9), confirm_button_label)
          )
        )
      )

      button = Yast::UI.UserInput
      Yast::UI.CloseDialog

      button == :ok
    end

    def input_loop
      loop do
        richtext_normal_cursor(Id(:proposal))
        # bnc #431567
        # Some proposal module can change it while called
        assign_next_button

        input = Yast::UI.UserInput

        return :next if input == :accept
        return :abort if input == :cancel

        log.info "Proposal - UserInput: '#{input}'"
        richtext_busy_cursor(Id(:proposal))

        case input
        when ::Integer # tabs
          switch_to_tab(input)

        when ::String # hyperlink
          input = submod_ask_user(input)

          # The workflow_sequence doesn't get handled as a workflow sequence
          # so we have to do this special case here. Kind of broken.
          return :finish if input == :finish

        when :finish
          return :finish

        when :abort
          abort_mode = Yast::Stage.initial ? :painless : :incomplete
          return :abort if Yast::Popup.ConfirmAbort(abort_mode)

        when :reset_to_defaults
          next unless Yast::Popup.ContinueCancel(
            # question in a popup box
            _("Really reset everything to default values?") + "\n" +
              # explain consequences of a decision
              _("You will lose all changes.")
          )
          make_proposal(true, false) # force_reset

        when :export_config
          export_config

        when :skip, :dontskip
          handle_skip

        when :next
          input = pre_continue_handling
          if input == :next
            # anything that needs to be done before
            # real installation starts

            write_settings unless @skip

            return :next
          end

        when :back
          Yast::Wizard.SetNextButton(:next, Yast::Label.NextButton) if Yast::Stage.initial
          return :back
        end
      end # while input loop

      nil
    end

    def switch_to_tab(input)
      @current_tab = input
      load_matching_submodules_list
      @proposal = ""
      @submodules_presentation.each do |mod|
        @proposal << (@html[mod] || "")
      end
      display_proposal(@proposal)
      submod_descriptions_and_build_menu
    end

    def export_config
      path = Yast::UI.AskForSaveFileName("/", "*.xml", _("Location of Stored Configuration"))
      return unless path

      # force write, so it always write profile even if user do not want
      # to store profile after installation
      Yast::WFM.CallFunction("clone_proposal", ["Write", "force" => true, "target_path" => path])
      raise _("Failed to store configuration. Details can be found in log.") unless File.exist?(path)
    end

    def handle_skip
      if Yast::UI.QueryWidget(Id(:skip), :Value)
        # User doesn't want to use any of the settings
        Yast::UI.ChangeWidget(
          Id(:proposal),
          :Value,
          Yast::HTML.Newlines(3) +
            # message show when user has disabled the configuration
            Yast::HTML.Para(_("Skipping configuration upon user request"))
        )
        Yast::UI.ChangeWidget(Id(:menu), :Enabled, false)
      else
        # User changed his mind and wants the settings back - recreate them
        make_proposal(false, false)
        Yast::UI.ChangeWidget(Id(:menu), :Enabled, true)
      end
    end

    def pre_continue_handling
      @skip = if Yast::UI.WidgetExists(Id(:skip))
                Yast::UI.QueryWidget(Id(:skip), :Value)
              else
                true
              end
      skip_blocker = Yast::UI.WidgetExists(Id(:skip)) && @skip
      if @have_blocker && !skip_blocker
        # error message is a popup
        Yast::Popup.Error(
          _(
            "The proposal contains an error that must be\nresolved before continuing.\n"
          )
        )
        return nil
      end

      if Yast::Stage.stage == "initial"
        input = Yast::WFM.CallFunction("inst_doit", [])
      # bugzilla #219097, #221571, yast2-update on running system
      elsif Yast::Stage.stage == "normal" && Yast::Mode.update
        input = confirm_update ? :next : nil
        log.info "Update not confirmed, returning back..." unless input
      end

      input
    end

    # Display preformatted proposal in the RichText widget
    #
    # @param [String] proposal human readable proposal preformatted in HTML
    #
    def display_proposal(proposal)
      if Yast::UI.WidgetExists(Id(:proposal))
        Yast::UI.ChangeWidget(Id(:proposal), :Value, proposal)
      else
        Yast::Builtins.y2error(-1, "Widget `proposal does not exist")
      end

      nil
    end

    def check_windows_left
      if !Yast::UI.WidgetExists(Id(:proposal))
        Yast::Builtins.y2error(-1, "Widget `proposal is not active!!!")
        log.info "--- Current widget tree ---"
        Yast::UI.DumpWidgetTree
        log.info "--- Current widget tree ---"
      end

      nil
    end

    # Call a submodule's AskUser() function.
    #
    # @param [String] submodule	name of the submodule's proposal dispatcher
    # @param  has_next		force a "next" button even if the submodule would otherwise rename it
    # @return workflow_sequence see proposal-API.txt
    #
    def submod_ask_user(input)
      # Call the AskUser() function
      ask_user_result = @store.handle_link(input)

      workflow_sequence = ask_user_result["workflow_sequence"] || :next
      language_changed = ask_user_result.fetch("language_changed", false)
      mode_changed = ask_user_result.fetch("mode_changed", false)

      if ![:cancel, :back, :abort, :finish].include?(workflow_sequence)
        if language_changed
          retranslate_proposal_dialog
          Yast::Pkg.SetTextLocale(Yast::Language.language)
          Yast::Pkg.SetPackageLocale(Yast::Language.language)
          Yast::Pkg.SetAdditionalLocales([Yast::Language.language])
        end

        if mode_changed
          Yast::Wizard.SetHelpText(@store.help_text(@current_tab))

          build_dialog
          load_matching_submodules_list
          log.error "i'm in dutch" unless submod_descriptions_and_build_menu
        end

        # Make a new proposal based on those user changes
        make_proposal(false, language_changed)
      end

      # There might be some UI layers left
      # we need to close them
      check_windows_left

      workflow_sequence
    end

    def make_proposal(force_reset, language_changed)
      tab_to_switch = 999
      current_tab_affected = false
      @have_blocker = false

      Yast::UI.ReplaceWidget(
        Id("inst_proposal_progress"),
        ProgressBar(
          Id("pb_ip"),
          "",
          2 * @store.proposal_names.size,
          0
        )
      )

      @html = {}
      @store.proposal_names.each do |submod|
        prop = html_header(submod)
        # BNC #463567
        # Submod already called
        if @submods_already_called.include?(submod)
          # busy message
          message = _("Adapting the proposal to the current settings...")
        # First run
        else
          # busy message;
          message = _("Analyzing your system...")
          @submods_already_called << submod
        end
        @html[submod] = prop + Yast::HTML.Para(message)
      end

      Yast::Wizard.DisableNextButton
      Yast::UI.BusyCursor

      submodule_nr = 0
      make_proposal_callback = proc do |submod, prop_map|
        submodule_nr += 1
        Yast::UI.ChangeWidget(Id("pb_ip"), :Value, submodule_nr)
        prop = html_header(submod)

        # check if it is needed to switch to another tab
        # because of an error
        if Yast::Builtins.haskey(@mod2tab, submod)
          log.info "Mod2Tab: '#{@mod2tab[submod]}'"
          warn_level = prop_map["warning_level"]
          if [:blocker, :fatal, :error].include?(warn_level)
            # bugzilla #237291
            # always switch to more detailed tab only
            # value 999 means to keep current tab, in case of error,
            # tab must be switched (bnc #441434)
            if @mod2tab[submod] > tab_to_switch ||
                tab_to_switch == 999
              tab_to_switch = @mod2tab[submod]
            end
            current_tab_affected = true if @mod2tab[submod] == @current_tab
          end
        end

        submodule_nr += 1
        Yast::UI.ChangeWidget(Id("pb_ip"), :Value, submodule_nr)

        if prop_map["language_changed"]
          retranslate_proposal_dialog
          submodule_nr = 0
        else
          prop << format_sub_proposal(prop_map)

          @html[submod] = prop

          # now do the complete html
          presentation_modules = @store.presentation_order
          presentation_modules = presentation_modules[@current_tab] if @store.tabs?
          proposal = presentation_modules.reduce("") do |res, mod|
            res << (@html[mod] || "")
          end
          display_proposal(proposal)
        end
      end

      @store.make_proposals(
        force_reset:      force_reset,
        language_changed: language_changed,
        callback:         make_proposal_callback
      )

      # FATE #301151: Allow YaST proposals to have help texts
      Yast::Wizard.SetHelpText(@store.help_text(@current_tab))

      if @store.tabs? && Yast::Ops.less_than(tab_to_switch, 999) && !current_tab_affected
        switch_to_tab(tab_to_switch)
      end

      # now do the display-only proposals

      Yast::UI.ReplaceWidget(Id("inst_proposal_progress"), Empty())
      Yast::Wizard.EnableNextButton
      Yast::UI.NormalCursor

      nil
    end

    def format_sub_proposal(prop)
      html = ""
      warning = prop["warning"] || ""

      if !warning.empty?
        level = prop["warning_level"] || :warning

        case level
        when :notice
          warning = Yast::HTML.Bold(warning)
        when :warning
          warning = Yast::HTML.Colorize(warning, "red")
        when :error
          warning = Yast::HTML.Colorize(warning, "red")
        when :blocker, :fatal
          @have_blocker = true
          warning = Yast::HTML.Colorize(warning, "red")
        end

        html << Yast::HTML.Para(warning)
      end

      preformatted_prop = prop["preformatted_proposal"] || ""

      if preformatted_prop.empty?
        # fallback proposal, means usually an internal error
        raw_prop = prop["raw_proposal"] || [_("ERROR: No proposal")]
        html << Yast::HTML.List(raw_prop)
      else
        html << preformatted_prop
      end

      html
    end

    # Call a submodule's Write() function.
    #
    # @param [String] submodule	name of the submodule's proposal dispatcher
    # @return success		true if Write() was successful of if there is no Write() function
    #
    def submod_write_settings(submodule)
      result = Yast::WFM.CallFunction(submodule, ["Write", {}]) || {}

      result.fetch("success", true)
    end

    # Call each submodule's "Write()" function to let it write its settings,
    # i.e. the settings effective.
    #
    def write_settings
      success = true

      @store.proposal_names do |submod|
        submod_success = submod_write_settings(submod)
        submod_success = true if submod_success.nil?
        log.error "Write() failed for submodule #{submod}" unless submod_success
        success &&= submod_success
      end

      return nil if success

      log.error "Write() failed for one or more submodules"

      # Submodules handle their own error reporting
      # text for a message box
      Yast::Popup.TimedMessage(_("Configuration saved.\nThere were errors."), 3)
    end

    # Force a RichText widget to use the busy cursor
    #
    # @param [Object] widget_id  ID  of the widget, e.g. `id(`proposal)
    #
    def richtext_busy_cursor(widget_id)
      Yast::UI.ChangeWidget(widget_id, :Enabled, false)

      nil
    end

    # Switch a RichText widget back to use the normal cursor
    #
    # @param [Object] widget_id  ID  of the widget, e.g. `id(`proposal)
    #
    def richtext_normal_cursor(widget_id)
      Yast::UI.ChangeWidget(widget_id, :Enabled, true)

      nil
    end

    def retranslate_proposal_dialog
      log.debug "Retranslating proposal dialog"

      build_dialog
      Yast::ProductControl.RetranslateWizardSteps
      Yast::Wizard.RetranslateButtons
      submod_descriptions_and_build_menu

      nil
    end

    def load_matching_submodules_list
      Yast::Builtins.y2milestone(
        "getting proposals for stage: \"%1\" mode: \"%2\" proposal type: \"%3\"",
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )

      if @store.proposal_names.empty?
        log.error "No proposals available"
        return :abort
      end

      if @store.tabs?
        log.info "Proposal uses tabs"
        @submodules_presentation = @store.presentation_order[@current_tab]
        @mod2tab = {}
        @store.presentation_order.each_index do |index|
          @store.presentation_order[index].each do |mod|
            @mod2tab[mod] = index
          end
        end

        p = Yast::AutoinstConfig.getProposalList
        @submodules_presentation = Yast::Builtins.filter(@submodules_presentation) do |v|
          Yast::Builtins.contains(p, v) || p == []
        end
      else
        log.info "Proposal doesn't use tabs"

        # setup the list
        @submodules_presentation = @store.presentation_order

        p = Yast::AutoinstConfig.getProposalList

        if !p.nil? && p != []
          # array intersection
          @submodules_presentation &= v
        end
      end

      log.info "Presentation order: #{@submodules_presentation}"
      log.info "Execution order: #{@store.proposal_names}"

      nil
    end

    def skip_buttons
      # radiobuttons
      RadioButtonGroup(
        VBox(
          VSpacing(1),
          Left(
            RadioButton(
              Id(:skip),
              Opt(:notify),
              # Check box: Skip all the configurations in this dialog -
              # do this later manually or not at all
              # Translators: About 40 characters max,
              # use newlines for longer translations.
              # radio button
              _("&Skip Configuration"),
              false
            )
          ),
          Left(
            RadioButton(
              Id(:dontskip),
              Opt(:notify),
              # radio button
              _("&Use Following Configuration"),
              true
            )
          ),
          VSpacing(1)
        )
      )
    end

    def build_dialog
      headline = @store.headline

      if Yast::UI.TextMode()
        change_point = ReplacePoint(
          Id(:rep_menu),
          # menu button
          MenuButton(Id(:menu_dummy), _("&Yast::Change..."), [Item(Id(:dummy), "")])
          )
      elsif @hide_export
        change_point = Empty()
      else
        change_point = PushButton(
          Id(:export_config),
          # menu button
          _("&Export Configuration")
          )
      end

      # change menu
      menu_box = VBox(
        HBox(
          HStretch(),
          change_point,
          HStretch()
        ),
        ReplacePoint(Id("inst_proposal_progress"), Empty())
      )

      enable_skip = @store.can_be_skipped?

      rt = RichText(
        Id(:proposal),
        Yast::HTML.Newlines(3) +
          # Initial contents of proposal subwindow while proposals are calculated
          Yast::HTML.Para(_("Analyzing your system..."))
      )

      if @store.tabs?
        tab_labels = @store.tab_labels
        if Yast::UI.HasSpecialWidget(:DumbTab)
          panes = tab_labels.map.with_index(0) do |label, id|
            Item(Id(id), label, label == tab_labels.first)
          end
          rt = DumbTab(Id(:_cwm_tab), panes, rt)
        else
          box = HBox()
          tabbar = tab_labels.map.with_index(0) do |label, id|
            box.params << PushButton(Id(id), label)
          end
          rt = VBox(Left(tabbar), Frame("", rt))
        end
      end

      if !enable_skip
        vbox = VBox(
          # Help message between headline and installation proposal / settings summary.
          # May contain newlines, but don't make it very much longer than the original.
          Left(
            Label(
              if Yast::UI.TextMode()
                _(
                  "Click a headline to make changes or use the \"Yast::Change...\" menu below."
                )
              else
                _(
                  "Click a headline to make changes."
                )
              end
            )
          ),
          rt,
          menu_box
        )
      else
        vbox = VBox(skip_buttons, HBox(HSpacing(4), rt), menu_box)
      end

      Yast::Wizard.SetContents(
        headline, # have_next_button
        vbox,
        @store.help_text(@current_tab),
        Yast::GetInstArgs.enable_back, # have_back_button
        false
      )
      set_icon

      if Yast::UI.WidgetExists(:_cwm_tab)
        Yast::UI.ChangeWidget(Id(:_cwm_tab), :CurrentItem, @current_tab)
      else
        log.info "Not using CWM tabs..."
      end

      nil
    end

    def submod_descriptions_and_build_menu
      return true unless Yast::UI.TextMode # have menu only in text mode

      # now build the menu button
      menu_list = @submodules_presentation.each_with_object([]) do |submod, menu|
        descr = @store.description_for(submod) || {}
        next if descr.empty?

        id = descr["id"]
        if descr.key? "menu_titles"
          descr["menu_titles"].each do |i|
            id2 = i["id"]
            title = i["title"]
            if id2 && title
              menu << Item(Id(id2), title + "...")
            else
              log.info "Invalid menu item: #{i}"
            end
          end
        else
          menu_title = descr["menu_title"] ||
            descr["rich_text_title"] ||
            submod

          menu << Item(Id(id), menu_title + "...")
        end
      end

      # menu button item
      menu_list << Item(Id(:reset_to_defaults), _("&Reset to defaults"))
      menu_list << Item(Id(:export_config), _("&Export Configuration")) unless @hide_export

      # menu button
      Yast::UI.ReplaceWidget(
        Id(:rep_menu),
        MenuButton(Id(:menu), _("&Change..."), menu_list)
      )

      !@store.descriptions.empty?
    end

    def set_icon
      Yast::Wizard.SetTitleIcon(@store.icon)

      nil
    end

    def assign_next_button
      if Yast::Stage.initial && @proposal_mode == "initial"
        Yast::Wizard.SetNextButton(
          :next,
          # FATE #120373
          Yast::Mode.update ? _("&Update") : _("&Install")
        )
      end

      nil
    end

    def html_header(submod)
      title = @store.title_for(submod)
      heading = if title.include?("<a")
                  title
                else
                  Yast::HTML.Link(
                    title,
                    @store.id_for(submod)
                  )
                end

      Yast::HTML.Heading(heading)
    end
  end
end
