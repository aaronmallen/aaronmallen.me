# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class ContextBar < Component
          KEY = "?"

          prop :current, Blog::Types::Instance(Structs::Section).optional
          prop :alert, Blog::Types::Bool, default: false

          def view_template
            div(class: "ctx-bar") do
              div(class: "ctx-bar-content") do
                where
                back
                jump
                keys
              end
            end
          end

          private

          def alert_dot
            return unless @alert

            span(class: "ctx-dot", aria: { hidden: "true" })
            whitespace
            span(class: "sr-only") { t(".alert") }
          end

          def back
            return if @current&.path == today

            a(class: "ctx-btn", href: today) do
              IconLabel(icon: "fa-solid fa-arrow-left") { t(".back") }
            end
          end

          def jump
            button(type: "button", class: "ctx-btn jump", data: { palette_open: true }) do
              IconLabel(icon: "fa-solid fa-magnifying-glass") { t(".jump") }
              alert_dot
              whitespace
              span(class: "kbd", aria: { hidden: "true" }) { t(".shortcut") }
            end
          end

          def keys
            label = t(".keys")

            button(
              type: "button", class: "ctx-btn", aria: { label: }, title: label,
              data: { dialog_open: KeyHelp::ID, key: KEY, key_label: label, key_help_open: true },
            ) do
              Icon("fa-regular fa-keyboard")
              span(class: "kbd", aria: { hidden: "true" }) { KEY }
            end
          end

          def today = path(:admin_root)

          def where
            return unless @current

            span(class: "ctx-where") do
              IconLabel(icon: ["fa-solid", @current.icon, "ctx-where-icon"]) { t(@current.group_key) }
              whitespace
              span(class: "ctx-where-sep") { t(".separator") }
              whitespace
              span(class: "ctx-where-name") { t(@current.label_key) }
            end
          end
        end
      end
    end
  end
end
