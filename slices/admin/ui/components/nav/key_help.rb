# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class KeyHelp < Component
          ID = "key-help"
          ROWS = "[data-key-list] [data-key-row]"
          TITLE_ID = "key-help-title"
          FIXED = [
            [%w[j], ".next", ROWS],
            [%w[k], ".previous", ROWS],
            [%w[↵], ".open", ROWS],
            [%w[⌘/ Ctrl+/], ".palette", nil],
            [%w[Alt+↑ Alt+↓], ".reorder", "[data-task-grip]:not([hidden])"],
          ].freeze

          def view_template
            Dialog(id: ID, title_id: TITLE_ID, title: t(".title"), data: { dialog: true, key_help: true }) do
              dl(class: "keys", data: { key_help_list: true }) { FIXED.each { fixed(*it) } }
              row_template
            end
          end

          private

          def fixed(keys, label_key, needs)
            div(class: "keys-row", data: { key_help_needs: needs }) do
              dt(class: "keys-keys") { keys.each { kbd(class: "kbd") { it } } }
              dd(class: "keys-label") { t(label_key) }
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
