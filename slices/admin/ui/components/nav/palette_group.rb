# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteGroup < Component
          prop :id, Blog::Types::String
          prop :heading, Blog::Types::String
          prop :data, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template(&)
            div(role: "group", aria: { labelledby: @id }, data: { palette_group: true, **@data }) do
              p(id: @id, class: "pal-g") { @heading }
              yield if block_given?
            end
          end
        end
      end
    end
  end
end
