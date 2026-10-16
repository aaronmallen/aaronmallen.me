# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SnoozeAll < Component
          DIALOG = "inbox-snooze-all"

          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(API::Structs::InboxRow))

          def view_template
            Button(small: true, icon: "fa-solid fa-bell-slash", **Dialog.opens(DIALOG)) { t(".label") }
            Dialog(id: DIALOG, title: t(".title")) do |dialog|
              SnoozeForm(id: DIALOG, dialog:, action: path(:admin_inbox_snooze_all)) do
                @rows.each { input(type: "hidden", name: SeeAll::FIELDS.fetch(it.kind), value: it.record.id) }
              end
            end
          end
        end
      end
    end
  end
end
