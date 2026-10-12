# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Bulk < Component
          ACT = Blog::Types::MessageBulkAction
          ID = "mail-bulk"

          prop :list, Blog::Types::Hash
          prop :page, Blog::Types::Integer

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_mail), label: t(".label"), fields:) do |bar|
              bar.act(ACT["read"], icon: "fa-regular fa-envelope-open", label: t(".read"))
              bar.act(ACT["unread"], icon: "fa-regular fa-envelope", label: t(".unread"))
              bar.act(ACT["delete"], icon: "fa-regular fa-trash-can", label: t(".delete"), variant: :warn, data:)
            end
          end

          private

          def data = { confirm: t(".confirm_delete") }

          def fields = { **@list, **Blog::Structs::Page.query(@page) }
        end
      end
    end
  end
end
