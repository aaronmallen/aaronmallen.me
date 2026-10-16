# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Mail
        class BulkMenu < View
          ACT = Blog::Types::MessageBulkAction
          ICON = Components::Mail::ActIcon
          INBOX = Blog::Types::MailFolder["inbox"]
          MARKS = { ACT["read"] => ".read", ACT["unread"] => ".unread", ACT["star"] => ".star" }.freeze
          TRASH = Blog::Types::MailFolder["trash"]

          layout nil

          prop :ids, Blog::Types::Array.of(Blog::Types::Integer)
          prop :list, Blog::Types::Hash
          prop :fields, Blog::Types::Hash
          prop :labels, Blog::Types::Hash
          prop :accounts, Blog::Types::Hash

          def view_template
            ContextMenu(label: t(".label", count: @ids.size)) do |menu|
              @list[:folder] == TRASH ? trash(menu) : filed(menu)
            end
          end

          private

          def act(menu, act, label, icon: ICON[act], **)
            menu.post(label, action: path(:admin_bulk_mail), icon:, fields: { **picked, act: }, **)
          end

          def count = @ids.size

          def filed(menu)
            act(menu, ACT["archive"], t(".archive", count:))
            MARKS.each { |act, key| act(menu, act, t(key)) }
            snooze(menu)
            menu.separator
            files(menu)
            menu.separator
            act(menu, ACT["trash"], t(".delete", count:), warn: true, confirm: t(".confirm"))
          end

          def files(menu)
            Components::Mail::MoveMenu(menu:, fields: picked, except: (ACT["inbox"] if @list[:folder] == INBOX))
            labels(menu)
          end

          def label(menu, account, name)
            fields = { **picked, act: ACT["label"], label: "#{account}:#{name}" }
            hint = @accounts[account] unless @list[:account]

            menu.post("#{Components::Tag::PREFIX}#{name}", action: path(:admin_bulk_mail), hint:, fields:)
          end

          def labels(menu)
            shown = @list[:account] ? @labels.slice(@list[:account]) : @labels
            return if shown.empty?

            menu.sub(t(".label_as"), icon: "fa-solid fa-tag") do
              shown.each { |account, names| names.each { |(name, _)| label(menu, account, name) } }
            end
          end

          def picked = { **@fields, "ids[]": @ids }

          def snooze(menu)
            action = path(:admin_snooze_bulk_mail)

            Components::Inbox::SnoozeMenu(menu:, kind: "message", id: @ids.first, action:, fields: picked)
          end

          def trash(menu)
            act(menu, ACT["inbox"], t(".restore", count:), icon: :restore)
            menu.separator
            act(menu, ACT["delete"], t(".delete_forever", count:), warn: true, confirm: t(".confirm_forever"))
          end
        end
      end
    end
  end
end
