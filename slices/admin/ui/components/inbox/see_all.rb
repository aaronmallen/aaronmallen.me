# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SeeAll < Component
          FIELDS = { task: "tasks[]", message: "messages[]", webmention: "webmentions[]" }.freeze

          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Repos::InboxQueries::Row))

          def view_template
            Form(action: path(:admin_inbox_see_all), data: { confirm: t(".confirm") }) do
              @rows.each { input(type: "hidden", name: FIELDS.fetch(it.kind), value: it.record.id) }
              Button(type: "submit", small: true, icon: "fa-solid fa-check-double") { t(".label") }
            end
          end
        end
      end
    end
  end
end
