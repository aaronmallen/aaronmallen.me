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
          LABELS = {
            CANCEL => ".cancel",
            COMPLETE => ".complete",
            DELETE => ".delete",
            Blog::Types::TaskBulkAction["move"] => ".move",
            Blog::Types::TaskBulkAction["tag"] => ".tag",
            Blog::Types::TaskBulkAction["untag"] => ".untag",
          }.freeze
          MOVE = Blog::Types::TaskBulkAction["move"]
          TAG = Blog::Types::TaskBulkAction["tag"]
          UNTAG = Blog::Types::TaskBulkAction["untag"]

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer
          prop :query, Blog::Types::String

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_tasks), label: t(".label"), fields:) do
              button(type: "submit", name: ACT, value: TAG, hidden: true, tabindex: "-1")
              act(COMPLETE, "fa-solid fa-check", variant: :pri)
              act(CANCEL, "fa-solid fa-ban")
              move
              tagging
              act(DELETE, "fa-regular fa-trash-can", variant: :warn, data: confirm)
            end
          end

          private

          def act(value, icon, variant: nil, data: nil)
            Button(type: "submit", variant:, small: true, name: ACT, value:, data:, icon:) do
              t(LABELS.fetch(value))
            end
          end

          def confirm = { confirm: t(".confirm_delete") }

          def fields
            { filter: @filter, **(@query.empty? ? {} : { q: @query }), **Blog::Structs::Page.query(@page) }
          end

          def move
            div(class: "bulk-group") do
              Select(name: "to", class: "bulk-field", aria: { label: t(".move_to") }, selected: nil, options: places)
              act(MOVE, "fa-solid fa-arrow-right")
            end
          end

          def places
            lists = Blog::Types::TaskFilter.values.to_h { [it, t(Helpers::TaskLists.title(it))] }

            { Blog::Constants::EMPTY_STRING => t(".pick_list"), **lists }
          end

          def tagging
            div(class: "bulk-group") do
              Input(name: "tag", class: "bulk-field", autocomplete: "off", placeholder: t(".tag_placeholder"),
                    aria: { label: t(".tag_name") })
              act(TAG, "fa-solid fa-tag")
              act(UNTAG, "fa-solid fa-xmark")
            end
          end
        end
      end
    end
  end
end
