# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class KeyHelp < Component
          ID = "key-help"
          ROWS = "[data-key-list] [data-key-row]"
          TITLE_ID = "key-help-title"
          ATTRIBUTES = {
            id: ID, class: "task-dialog", hidden: true, aria: { labelledby: TITLE_ID },
            data: { dialog: true, key_help: true },
          }.freeze
          FIXED = [
            [%w[j], ".next", ROWS],
            [%w[k], ".previous", ROWS],
            [%w[↵], ".open", ROWS],
            [%w[⌘/ Ctrl+/], ".palette", nil],
            [%w[Alt+↑ Alt+↓], ".reorder", "[data-task-grip]:not([hidden])"],
          ].freeze

          def view_template
            dialog(**ATTRIBUTES) do
              div(class: "task-dialog-box") do
                head
                dl(class: "keys", data: { key_help_list: true }) { FIXED.each { fixed(*it) } }
                row_template
              end
            end
          end

          private

          def fixed(keys, label_key, needs)
            div(class: "keys-row", data: { key_help_needs: needs }) do
              dt(class: "keys-keys") { keys.each { kbd(class: "kbd") { it } } }
              dd(class: "keys-label") { t(label_key) }
            end
          end

          def head
            div(class: "task-dialog-head") do
              h2(id: TITLE_ID, class: "card-title") { t(".title") }
              Button(
                variant: :gh, small: true, aria: { label: t(".close") }, data: { dialog_close: true },
                icon: "fa-solid fa-xmark",
              )
            end
          end

          def row_template
            template(data: { key_help_row: true }) do
              div(class: "keys-row", data: { key_help_added: true }) do
                dt(class: "keys-keys", data: { key_help_keys: true })
                dd(class: "keys-label", data: { key_help_label: true })
              end
            end
          end
        end
      end
    end
  end
end
