# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SnoozedList < Component
          PILLS = {
            message: [:sand, ".kinds.message"], task: [:green, ".kinds.task"], webmention: [:pink, ".kinds.webmention"],
          }.freeze

          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Queries::Inbox::Row))

          def view_template
            Card(title: t(".title"), id: "inbox-snoozed") do
              details(class: "time-group") do
                summary(class: "time-row") do
                  Icon("fa-solid fa-chevron-right time-caret")
                  span { t(".summary", count: @rows.size) }
                end
                @rows.each { row(it) }
              end
            end
          end

          private

          def meta(found)
            color, label_key = PILLS.fetch(found.kind)

            Pill(color:) { t(label_key) }
            span { Stamped(text: t(".wakes", at: Stamped::MARK), at: found.at) }
          end

          def row(found)
            ListItem(id: "snoozed-#{found.kind}-#{found.record.id}", title: title(found)) do |item|
              item.meta { p(class: "wm-meta") { meta(found) } }
              Form(action: path(:admin_inbox_wake, kind: found.kind, id: found.record.id)) do
                Button(type: "submit", small: true) { t(".wake") }
              end
            end
          end

          def title(found)
            case found.kind
            when :message then found.record.subject
            when :webmention then found.record.author_label
            else found.record.title
            end
          end
        end
      end
    end
  end
end
