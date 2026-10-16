# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Bulk < Component
          ACT = Blog::Types::MessageBulkAction
          CHOICES = {
            "to" => [ACT["move"], ".move_to", ".move"],
            "label" => [ACT["label"], ".label_pick", ".label_as"],
          }.freeze
          FILED = [
            [ACT["archive"], ActIcon[ACT["archive"]], ".archive", nil],
            [ACT["read"], nil, ".read", :gh],
            [ACT["unread"], nil, ".unread", :gh],
          ].freeze
          ID = "mail-bulk"
          INBOX = Blog::Types::MailMove["inbox"]
          MOVES = Blog::Types::MailMove.values.to_h { [it, "ui.components.mail.bulk.moves.#{it}"] }.freeze
          TRASH = Blog::Types::MailFolder["trash"]

          prop :list, Blog::Types::Hash
          prop :page, Blog::Types::Integer
          prop :labels, Blog::Types::Hash
          prop :chips, Blog::Types::Hash
          prop :count, Blog::Types::Integer

          def view_template
            BulkBar(
              id: ID, action: path(:admin_bulk_mail), label: t(".label"), fields:,
              menu: path(:admin_mail_bulk_menu, **fields), all: t(".all", count: @count), hint: t(".hint"),
              toggled: true,
            ) do |bar|
              @list[:folder] == TRASH ? trash(bar) : filed(bar)
            end
          end

          private

          def choose(bar, name, options)
            act, prompt, label = CHOICES.fetch(name)
            bar.choose(name, act, prompt: t(prompt), options:, icon: ActIcon[act], label: t(label))
          end

          def data = { confirm: t(".confirm_delete_forever") }

          def fields = { **@list, **Blog::Structs::Page.query(@page) }

          def filed(bar)
            FILED.each { |act, icon, label, variant| bar.act(act, icon:, label: t(label), variant:) }
            choose(bar, "to", moves)
            labels = label_options
            choose(bar, "label", labels) if labels.any?
            bar.act(ACT["trash"], icon: ActIcon[ACT["trash"]], label: t(".trash"), variant: :warn)
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
            bar.act(ACT["inbox"], icon: :restore, label: t(".restore"))
            delete = ACT["delete"]
            bar.act(delete, icon: ActIcon[delete], label: t(".delete_forever"), variant: :warn, data:)
          end
        end
      end
    end
  end
end
