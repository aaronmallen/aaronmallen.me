# frozen_string_literal: true

module Blog
  module UI
    module Components
      class SettingsMenu < Component
        APPEARANCE_ID = "settings-menu-appearance"
        PANEL_ID = "settings-menu"

        THEMES = [
          %w[light fa-sun .light].freeze,
          %w[dark fa-moon .dark].freeze,
        ].freeze

        prop :session, Blog::Types.Interface(:csrf_token, :signed_in?)

        def view_template
          div(class: "settings-menu") do
            toggle
            panel
          end
        end

        private

        def admin_items(admin_session)
          hr(class: "settings-menu-separator")
          a(class: "settings-menu-option", href: path(:admin_root)) do
            IconLabel(icon: "fa-solid fa-gauge") { t(".admin") }
          end
          sign_out_form(admin_session.csrf_token)
        end

        def admin_session
          @session if @session.signed_in?
        end

        def panel
          div(id: PANEL_ID, class: "settings-menu-panel") do
            div(role: "group", aria: { labelledby: APPEARANCE_ID }) do
              span(id: APPEARANCE_ID, class: "settings-menu-heading") { t(".appearance") }
              THEMES.each { |(theme, icon, label_key)| theme_option(theme:, icon:, label_key:) }
            end
            signed_in = admin_session
            admin_items(signed_in) if signed_in
          end
        end

        def sign_out_form(token)
          Form(action: path(:admin_sign_out), token:) do
            input(type: "hidden", name: "return_to", value: request.fullpath)
            button(type: "submit", class: "settings-menu-option") do
              IconLabel(icon: "fa-solid fa-right-from-bracket") { t(".sign_out") }
            end
          end
        end

        def theme_option(theme:, icon:, label_key:)
          button(
            type: "button",
            class: "settings-menu-option",
            aria: { pressed: "false" },
            data: { theme_choice: theme },
          ) do
            IconLabel(icon: ["fa-solid", icon]) { t(label_key) }
            Icon("fa-solid fa-check settings-menu-check")
          end
        end

        def toggle
          button(
            type: "button",
            class: "settings-menu-toggle",
            aria: { controls: PANEL_ID, expanded: "false", label: t(".toggle_label") },
            data: { disclosure: true },
          ) do
            Icon("fa-solid fa-gear")
          end
        end
      end
    end
  end
end
