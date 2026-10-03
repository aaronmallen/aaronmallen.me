# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Bulk < Component
          ACT = "act"
          CANCEL = Blog::Types::TaskBulkAction["cancel"]
          COMPLETE = Blog::Types::TaskBulkAction["complete"]
          DELETE = Blog::Types::TaskBulkAction["delete"]
          ID = "task-bulk"
          LABELS = { CANCEL => ".cancel", COMPLETE => ".complete", DELETE => ".delete" }.freeze

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer
          prop :query, Blog::Types::String

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_tasks), label: t(".label"), fields:) do
              act(COMPLETE, "fa-solid fa-check", variant: :pri)
              act(CANCEL, "fa-solid fa-ban")
              act(DELETE, "fa-regular fa-trash-can", variant: :warn, data: confirm)
            end
          end

          private

          def act(value, icon, variant: nil, data: nil)
            Button(type: "submit", variant:, small: true, name: ACT, value:, data:) do
              i(class: icon, aria: { hidden: "true" })
              span { t(LABELS.fetch(value)) }
            end
          end

          def confirm = { confirm: t(".confirm_delete"), confirm_styled: true }

          def fields
            { filter: @filter, **(@query.empty? ? {} : { q: @query }), **Blog::Page.query(@page) }
          end
        end
      end
    end
  end
end
