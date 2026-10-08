# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class AvatarMenu < Component
          HELP_KEY = "?"
          ID = "avatar-menu"
          SITE = [
            %i[writing fa-pen-nib .pages.writing].freeze,
            %i[about fa-user .pages.about].freeze,
            %i[projects fa-cube .pages.projects].freeze,
            %i[contact fa-envelope .pages.contact].freeze,
          ].freeze
          THEMES = [
            %w[light fa-sun .themes.light].freeze,
            %w[dark fa-moon .themes.dark].freeze,
          ].freeze

          prop :settings, Blog::Types::Array.of(Blog::Types::Instance(Structs::Section))

          def view_template
            button(type: "button", class: "avatar", popovertarget: ID, aria: { label: t(".label") }) do
              plain Hanami.app.settings.owner_name[0]
            end

            div(id: ID, class: "avatar-menu", popover: "auto") { entries }
          end

          private

          def entries
            site
            rule
            settings
            rule
            keys
            themes
            rule
            sign_out
          end

          def heading(key) = span(class: "avatar-menu-label") { t(key) }

          def item(icon, href: nil, **attributes, &)
            attributes = { class: "avatar-menu-item", **attributes }
            content = proc do
              Icon(["fa-solid", icon, "avatar-menu-icon"])
              yield
            end

            href ? a(href:, **attributes, &content) : button(type: "button", **attributes, &content)
          end

          def keys
            label = t(".keys")

            item(
              "fa-keyboard",
              data: { dialog_open: KeyHelp::ID, key: HELP_KEY, key_label: t(".show_keys"), key_help_open: true },
            ) do
              plain label
              span(class: "avatar-menu-key", aria: { hidden: "true" }) { HELP_KEY }
            end
          end

          def rule = hr(class: "avatar-menu-rule")

          def settings
            heading(".settings")
            @settings.each do |section|
              item(section.icon, href: section.path) { plain t(section.label_key) }
            end
          end

          def sign_out
            Form(action: path(:admin_sign_out)) do
              item("fa-right-from-bracket", type: "submit") { plain t(".sign_out") }
            end
          end

          def site
            heading(".site")
            SITE.each { |(route, icon, label_key)| item(icon, href: path(route)) { plain t(label_key) } }
          end

          def themes
            THEMES.each do |(theme, icon, label_key)|
              item(icon, aria: { pressed: "false" }, data: { theme_choice: theme }) do
                plain t(label_key)
                Icon("fa-solid fa-check avatar-menu-check")
              end
            end
          end
        end
      end
    end
  end
end
