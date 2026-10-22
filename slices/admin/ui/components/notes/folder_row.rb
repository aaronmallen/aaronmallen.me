# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class FolderRow < Component
          prop :icon, Blog::Types::String
          prop :href, Blog::Types::String
          prop :menu, Blog::Types::String
          prop :title, Blog::Types::String
          prop :pinned, Blog::Types::Bool, default: false

          def view_template(&)
            div(class: "nt-rw", data: { key_row: true, menu: @menu }) do
              div(class: "nt-ixr") do
                Icon(@icon)
                div do
                  title
                  yield
                end
              end
            end
          end

          private

          def title
            p(class: "nt-ixt") do
              a(class: "nt-rt", href: @href, data: { key_open: true }) { @title }
              Icon("fa-solid fa-thumbtack nt-pn", label: t(".pinned")) if @pinned
            end
          end
        end
      end
    end
  end
end
