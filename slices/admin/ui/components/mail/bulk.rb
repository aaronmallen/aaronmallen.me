# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Bulk < Component
          ACT = Blog::Types::MessageBulkAction
          CHOICES = {
            "to" => [ACT["move"], ".move_to", ".move", "fa-solid fa-arrow-right"],
            "label" => [ACT["label"], ".label_pick", ".label_as", "fa-solid fa-tag"],
          }.freeze
          FILED = [
            [ACT["archive"], "fa-solid fa-box-archive", ".archive"],
            [ACT["read"], "fa-regular fa-envelope-open", ".read"],
            [ACT["unread"], "fa-regular fa-envelope", ".unread"],
          ].freeze
          ID = "mail-bulk"
          INBOX = Blog::Types::MailMove["inbox"]
          MOVES = Blog::Types::MailMove.values.to_h { [it, "ui.components.mail.bulk.moves.#{it}"] }.freeze
          TRASH = Blog::Types::MailFolder["trash"]

          prop :list, Blog::Types::Hash
          prop :page, Blog::Types::Integer
          prop :labels, Blog::Types::Hash
          prop :chips, Blog::Types::Hash

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_mail), label: t(".label"), fields:,
                    menu: path(:admin_mail_bulk_menu, **fields)) do |bar|
              @list[:folder] == TRASH ? trash(bar) : filed(bar)
            end
          end

          private

          def choose(bar, name, options)
            act, pick, label, icon = CHOICES.fetch(name)
            div(class: "bulk-group") do
              Select(name:, class: "bulk-field", aria: { label: t(pick) }, options:, selected: nil)
              bar.act(act, icon:, label: t(label))
            end
          end

          def data = { confirm: t(".confirm_delete_forever") }

          def fields = { **@list, **Blog::Structs::Page.query(@page) }

          def filed(bar)
            FILED.each { |act, icon, label| bar.act(act, icon:, label: t(label)) }
            choose(bar, "to", moves)
            labels = label_options
            choose(bar, "label", labels) if labels.any?
            bar.act(ACT["trash"], icon: "fa-regular fa-trash-can", label: t(".trash"), variant: :warn)
          end

          def label_options
            @labels.flat_map do |account, names|
              names.map do |(name, _)|
                ["#{account}:#{name}", @list[:account] ? "##{name}" : "##{name} · #{@chips.fetch(account).first}"]
              end
            end.to_h
          end

          def moves
            moves = @list[:folder] == INBOX ? MOVES.except(INBOX) : MOVES
            moves.transform_values { t(it) }
          end

          def trash(bar)
            bar.act(ACT["inbox"], icon: "fa-solid fa-rotate-left", label: t(".restore"))
            bar.act(ACT["delete"], icon: "fa-regular fa-trash-can", label: t(".delete_forever"), variant: :warn, data:)
          end
        end
      end
    end
  end
end
