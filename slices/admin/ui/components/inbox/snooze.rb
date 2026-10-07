# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class Snooze < Component
          prop :kind, Blog::Types::String
          prop :id, Blog::Types::Integer

          def view_template
            Button(small: true, data: { dialog_open: dialog_id }) { t(".open") }
            Dialog(id: dialog_id, title_id: "#{dialog_id}-title", title: t(".title"), data: { dialog: true }) do
              SnoozeForm(action: path(:admin_inbox_snooze, kind: @kind, id: @id), field_id: "#{dialog_id}-until")
            end
          end

          private

          def dialog_id = "snooze-#{@kind}-#{@id}"
        end
      end
    end
  end
end
