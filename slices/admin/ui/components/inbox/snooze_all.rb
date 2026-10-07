# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SnoozeAll < Component
          DIALOG = "inbox-snooze-all"

          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Queries::Inbox::Row))

          def view_template
            Button(small: true, icon: "fa-solid fa-bell-slash", data: { dialog_open: DIALOG }) { t(".label") }
            Dialog(id: DIALOG, title_id: "#{DIALOG}-title", title: t(".title"), data: { dialog: true }) do
              SnoozeForm(action: path(:admin_inbox_snooze_all), field_id: "#{DIALOG}-until") do
                @rows.each { input(type: "hidden", name: SeeAll::FIELDS.fetch(it.kind), value: it.record.id) }
              end
            end
          end
        end
      end
    end
  end
end
