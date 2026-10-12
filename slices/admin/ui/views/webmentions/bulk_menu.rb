# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class BulkMenu < View
          SPAM = Blog::Types::WebmentionVerdict["spam"]
          VERDICTS = Components::WebmentionVerdict::VERDICTS.to_h do |verdict, (icon, label)|
            [verdict, [icon, "ui.components.webmention_verdict#{label}"]]
          end.freeze

          layout nil

          prop :ids, Blog::Types::Array.of(Blog::Types::Integer)
          prop :filter, Blog::Types::WebmentionStatus
          prop :fields, Blog::Types::Hash

          def view_template
            ContextMenu(label: t(".label", count: @ids.size)) do |menu|
              VERDICTS.except(@filter).each do |verdict, (icon, label)|
                fields = { **@fields, "ids[]": @ids, act: verdict }

                menu.post(t(label), action: path(:admin_bulk_webmentions), fields:, icon:, warn: verdict == SPAM)
              end
            end
          end
        end
      end
    end
  end
end
