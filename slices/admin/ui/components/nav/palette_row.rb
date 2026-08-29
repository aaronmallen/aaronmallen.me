# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteRow < Component
          prop :id, Blog::Types::String
          prop :icon, Blog::Types::String
          prop :text, Blog::Types::String, default: -> { "" }
          prop :label, Blog::Types::String.optional, default: nil
          prop :sub, Blog::Types::String.optional, default: nil
          prop :warn, Blog::Types::Bool, default: false
          prop :href, Blog::Types::String.optional, default: nil
          prop :add, Blog::Types::String.optional, default: nil
          prop :task, Blog::Types::Bool, default: false
          prop :hidden, Blog::Types::Bool, default: false

          def view_template
            div(
              id: @id, class: "pal-r", role: "option", hidden: @hidden, aria: { selected: "false" },
              data: {
                palette_option: true, palette_text: @text, palette_href: @href,
                palette_add: @add, palette_task: (true if @task),
              },
            ) do
              i(class: ["fa-solid", @icon, "pal-r-icon"], aria: { hidden: "true" })
              span(class: "pal-r-label", data: { palette_add_label: (true if @add) }) { @label }
              span(class: ["pal-r-sub", ("warn" if @warn)]) { @sub } if @sub
            end
          end
        end
      end
    end
  end
end
