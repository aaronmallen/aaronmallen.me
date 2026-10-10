# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class Bulk < Component
          ID = "webmention-bulk"
          VARIANTS = {
            Blog::Types::WebmentionVerdict["approved"] => :pri,
            Blog::Types::WebmentionVerdict["ignored"] => nil,
            Blog::Types::WebmentionVerdict["spam"] => :warn,
          }.freeze

          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_webmentions), label: t(".label"), fields:) do
              VARIANTS.except(@filter).each do |verdict, variant|
                WebmentionVerdict(verdict:, variant:, name: BulkBar::ACT, value: verdict)
              end
            end
          end

          private

          def fields = { status: @filter, **Blog::Structs::Page.query(@page) }
        end
      end
    end
  end
end
