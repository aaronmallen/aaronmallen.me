# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class Snooze < Component
          prop :kind, Blog::Types::String
          prop :id, Blog::Types::Integer
          prop :action, Blog::Types::String.optional, default: nil

          def view_template(&)
            Button(small: true, data: { dialog_open: dialog_id }) { t(".open") }
            Dialog(id: dialog_id, title: t(".title"), data: { dialog: true }) do |dialog|
              SnoozeForm(id: dialog_id, dialog:, action: @action || path(:admin_inbox_snooze, kind: @kind, id: @id), &)
            end
          end

          private

          def dialog_id = "snooze-#{@kind}-#{@id}"
        end
      end
    end
  end
end
