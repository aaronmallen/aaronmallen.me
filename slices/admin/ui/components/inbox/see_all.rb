# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SeeAll < Component
          FIELDS = { task: "tasks[]", message: "messages[]", webmention: "webmentions[]" }.freeze

          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Structs::InboxRow))

          def view_template
            ButtonForm(
              action: path(:admin_inbox_see_all), label: t(".label"), icon: "fa-solid fa-check-double",
              confirm: t(".confirm"), hidden: ids,
            )
          end

          private

          def ids = @rows.group_by { FIELDS.fetch(it.kind) }.transform_values { |rows| rows.map { it.record.id } }
        end
      end
    end
  end
end
