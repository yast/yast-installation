require "yast"
require "cwm/widget"
require "y2country/widgets/language_selection"
require "y2country/widgets/keyboard_selection"

Yast.import "Language"
Yast.import "Keyboard"

module Installation
  module Widgets
    # Widget to show a language and keyboard selector
    #
    # This widget relies on language and keyboard selectors included in
    # yast2-country. Additionally, a textfield which can be used by the user to
    # try the keyboard selection is included too.
    #
    # The main objective of this widget is to signal when language was changed.
    # In that case, #handle will return :language_changed interrupting the CWM
    # loop and giving the opportunity to translate the YaST interface.
    # See Installation::Clients::InstComplexWelcome for further information.
    class LanguageKeyboardSelection < CWM::CustomWidget
      # Constructor
      def initialize
        textdomain "installation"
      end

      # Widget value handler
      #
      # @return [:language_changed,nil] :language_changed is language was changed.
      # @see CWM::AbstractWidget#handle
      def handle
        return :language_changed if language_changed?
        return :keyboard_changed if keyboard_changed?
        nil
      end

      # Handle all events
      #
      # @return [true]
      # @see CWM::AbstractWidget#handle_all_events
      def handle_all_events
        true
      end

      # Widget content
      #
      # @return [Yast::Term] widget content
      # @see CWM::CustomWidget#contents
      def contents
        VBox(
          Left(
            HBox(
              HWeight(1, Left(language_selector)),
              HSpacing(3),
              HWeight(1, Left(keyboard_selector))
            )
          ),
          Left(
            HBox(
              HWeight(1, HStretch()),
              HSpacing(3),
              HWeight(1, Left(InputField(Id(:keyboard_test), Opt(:hstretch), _("K&eyboard Test"))))
            )
          )
        )
      end

    private

      # Return the language selector to be embedded
      #
      # @return [Yast::Term]
      # @see Y2Country::Widgets::LanguageSelection
      def language_selector
        @language_selector ||= Y2Country::Widgets::LanguageSelection.new(initial_language)
      end

      # Return the keyboard selector to be embedded
      #
      # @return [Yast::Term]
      # @see Y2Country::Widgets::KeyboardSelectionCombo
      def keyboard_selector
        @keyboard_selector ||= Y2Country::Widgets::KeyboardSelectionCombo.new(initial_keyboard)
      end

      # Determine whether the language has changed
      #
      # @return [Boolean] true if the language has changed
      def language_changed?
        initial_language != language_selector.value
      end

      # Determine wether the keyboard has changed
      #
      # @return [Boolean] true if the keyboard has changed
      def keyboard_changed?
        initial_keyboard != keyboard_selector.value
      end

      # Determine the default keyboard value
      #
      # @return [String] Keyboard layout
      def initial_keyboard
        return @initial_keyboard if @initial_keyboard
        @initial_keyboard =
          if Yast::Keyboard.user_decision
            Yast::Keyboard.current_kbd
          else
            Yast::Keyboard.GetKeyboardForLanguage(initial_language, "english-us")
          end

        Yast::Keyboard.Set(@initial_keyboard) if @initial_keyboard != Yast::Keyboard.current_kbd
        @initial_keyboard
      end

      # Determine the default language value
      #
      # @return [String] Language code
      def initial_language
        @initial_language ||= Yast::Language.language
      end
    end
  end
end
