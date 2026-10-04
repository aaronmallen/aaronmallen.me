# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Inbox
        class Index < View
          include Components::Inbox

          def initialize(rows:, slugs:)
            super()
            @rows = rows
            @slugs = slugs
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @rows.size))

            Card(title: t(".waiting"), data: { key_list: true }) do
              next Empty { t(".empty") } if @rows.empty?

              @rows.each { row(it) }
            end
          end

          private

          def row(found)
            case found.kind
            when :message then MessageItem(message: found.record)
            when :webmention then MentionItem(mention: found.record, slug: @slugs.fetch(found.record.post_id))
            else IssueItem(task: found.record)
            end
          end
        end
      end
    end
  end
end
