# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Inbox
        class Index < View
          include Components::Inbox

          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Repos::InboxQueries::Row))
          prop :snoozed, Blog::Types::Array.of(Blog::Types::Instance(API::Repos::InboxQueries::Row))
          prop :slugs, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::String)

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @rows.size)) { head_actions if @rows.any? }

            Card(class: "inbox-card") do
              div(data: { key_list: true }) do
                @rows.empty? ? Empty { t(".empty") } : @rows.each { row(it) }
              end
              SnoozedList(rows: @snoozed) if @snoozed.any?
            end
          end

          private

          def head_actions
            SeeAll(rows: @rows)
            SnoozeAll(rows: @rows)
          end

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
