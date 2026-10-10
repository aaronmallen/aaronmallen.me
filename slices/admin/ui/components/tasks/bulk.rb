# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Bulk < Component
          CANCEL = Blog::Types::TaskBulkAction["cancel"]
          COMPLETE = Blog::Types::TaskBulkAction["complete"]
          DELETE = Blog::Types::TaskBulkAction["delete"]
          ID = "task-bulk"
          MOVE = Blog::Types::TaskBulkAction["move"]
          TAG = Blog::Types::TaskBulkAction["tag"]
          UNTAG = Blog::Types::TaskBulkAction["untag"]

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer
          prop :query, Blog::Types::String

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_tasks), label: t(".label"), fields:) do |bar|
              bar.act(COMPLETE, icon: "fa-solid fa-check", label: t(".complete"), variant: :pri)
              bar.act(CANCEL, icon: "fa-solid fa-ban", label: t(".cancel"))
              move(bar)
              bar.tagging(tag: TAG, untag: UNTAG)
              bar.act(DELETE, icon: "fa-regular fa-trash-can", label: t(".delete"), variant: :warn, data: confirm)
            end
          end

          private

          def confirm = { confirm: t(".confirm_delete") }

          def fields
            { filter: @filter, **(@query.empty? ? {} : { q: @query }), **Blog::Structs::Page.query(@page) }
          end

          def move(bar)
            div(class: "bulk-group") do
              Select(name: "to", class: "bulk-field", aria: { label: t(".move_to") }, selected: nil, options: places)
              bar.act(MOVE, icon: "fa-solid fa-arrow-right", label: t(".move"))
            end
          end

          def places
            lists = Blog::Types::TaskFilter.values.to_h { [it, t(Helpers::TaskLists.title(it))] }

            { Blog::Constants::EMPTY_STRING => t(".pick_list"), **lists }
          end
        end
      end
    end
  end
end
