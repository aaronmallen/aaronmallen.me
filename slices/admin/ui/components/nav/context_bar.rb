# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class ContextBar < Component
          prop :current, Blog::Types::Instance(Structs::Section).optional
          prop :alert, Blog::Types::Bool, default: false

          def view_template
            div(class: "ctx-bar") do
              div(class: "ctx-bar-content") do
                where
                back
                jump
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
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".back") }
            end
          end

          def jump
            button(type: "button", class: "ctx-btn jump", data: { palette_open: true }) do
              i(class: "fa-solid fa-magnifying-glass", aria: { hidden: "true" })
              span { t(".jump") }
              alert_dot
              whitespace
              span(class: "kbd", aria: { hidden: "true" }) { t(".shortcut") }
            end
          end

          def today = path(:admin_root)

          def where
            return unless @current

            span(class: "ctx-where") do
              i(class: ["fa-solid", @current.icon, "ctx-where-icon"], aria: { hidden: "true" })
              span { t(@current.group_key) }
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
