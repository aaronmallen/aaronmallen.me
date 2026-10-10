# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SnoozedList < Component
          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Structs::InboxRow))

          def view_template
            details(id: "inbox-snoozed", class: "inbox-snoozed") do
              summary do
                Icon("fa-solid fa-chevron-right inbox-snoozed-caret")
                span { t(".summary", count: @rows.size) }
              end
              @rows.each { row(it) }
            end
          end

          private

          def meta(found)
            KindLabel(kind: found.kind)
            span { Stamped(text: t(".wakes", at: Stamped::MARK), at: found.at) }
          end

          def row(found)
            div(id: "snoozed-#{found.kind}-#{found.record.id}", class: "inbox-snoozed-row") do
              div(class: "inbox-row-main") do
                p(class: "inbox-snoozed-title") { title(found) }
                p(class: "inbox-meta") { meta(found) }
              end
              Form(action: path(:admin_inbox_wake, kind: found.kind, id: found.record.id)) do
                Button(type: "submit", variant: :gh, small: true) { t(".wake") }
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
