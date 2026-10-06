# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Bulk < Component
          ACT = "act"
          DELETE = Blog::Types::PostBulkAction["delete"]
          ID = "post-bulk"
          TAG = Blog::Types::PostBulkAction["tag"]

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_posts), label: t(".label"), fields:) do
              button(type: "submit", name: ACT, value: TAG, hidden: true, tabindex: "-1")
              tagging
              act(DELETE, "fa-regular fa-trash-can", t(".delete"), variant: :warn, data: confirm)
            end
          end

          private

          def act(value, icon, label, variant: nil, data: nil)
            Button(type: "submit", variant:, small: true, name: ACT, value:, data:, icon:) { label }
          end

          def confirm = { confirm: t(".confirm_delete"), confirm_styled: true }

          def fields = { status: @filter, **Blog::Page.query(@page) }

          def tagging
            div(class: "bulk-group") do
              Input(name: "tag", class: "bulk-field", autocomplete: "off", placeholder: t(".tag_placeholder"),
                    aria: { label: t(".tag_name") })
              act(TAG, "fa-solid fa-tag", t(".tag"))
            end
          end
        end
      end
    end
  end
end
