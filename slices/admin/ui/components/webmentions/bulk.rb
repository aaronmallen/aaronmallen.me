# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class Bulk < Component
          ACT = "act"
          ID = "webmention-bulk"
          VERDICTS = {
            Blog::Types::WebmentionVerdict["approved"] => ["fa-solid fa-check", ".approve", :pri],
            Blog::Types::WebmentionVerdict["ignored"] => ["fa-regular fa-eye-slash", ".ignore", nil],
            Blog::Types::WebmentionVerdict["spam"] => ["fa-solid fa-ban", ".spam", :warn],
          }.freeze

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_webmentions), label: t(".label"), fields:) do
              VERDICTS.except(@filter).each { |value, (icon, label, variant)| act(value, icon, label, variant) }
            end
          end

          private

          def act(value, icon, label, variant)
            Button(type: "submit", variant:, small: true, name: ACT, value:) do
              i(class: icon, aria: { hidden: "true" })
              span { t(label) }
            end
          end

          def fields = { status: @filter, **Blog::Page.query(@page) }
        end
      end
    end
  end
end
