# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SnoozeMenu < Component
          LABELS = "ui.components.inbox.snooze_form"

          prop :menu, Blog::Types::Instance(ContextMenu)
          prop :kind, Blog::Types::String
          prop :id, Blog::Types::Integer
          prop :action, Blog::Types::String.optional, default: nil
          prop :fields, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            now = Time.now
            today = Blog::TimeZone.today(now)

            @menu.sub(t(".snooze"), icon: "fa-regular fa-bell-slash") do
              SnoozeForm.quick_picks(now).each { |key, at| pick(key, at, today) }
            end
          end

          private

          def hint(at, today)
            day = Blog::TimeZone.today(at)
            day - today > 1 ? l(day, format: :short) : l(Blog::TimeZone.local(at), format: :clock)
          end

          def pick(key, at, today)
            action = @action || path(:admin_inbox_snooze, kind: @kind, id: @id)
            fields = { **@fields, pick: Blog::TimeZone.input_value(at) }
            label = "#{LABELS}.#{key}"

            @menu.post(t(label), action:, fields:, hint: hint(at, today))
          end
        end
      end
    end
  end
end
