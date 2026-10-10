# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Bulk < Component
          DELETE = Blog::Types::PostBulkAction["delete"]
          ID = "post-bulk"
          TAG = Blog::Types::PostBulkAction["tag"]

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_posts), label: t(".label"), fields:) do |bar|
              bar.tagging(tag: TAG)
              bar.act(DELETE, icon: "fa-regular fa-trash-can", label: t(".delete"), variant: :warn, data: confirm)
            end
          end

          private

          def confirm = { confirm: t(".confirm_delete") }

          def fields = { status: @filter, **Blog::Structs::Page.query(@page) }
        end
      end
    end
  end
end
