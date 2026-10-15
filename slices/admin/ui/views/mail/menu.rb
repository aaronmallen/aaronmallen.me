# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Mail
        class Menu < View
          ACT = Blog::Types::MessageBulkAction
          ICONS = {
            ACT["archive"] => "fa-solid fa-box-archive",
            ACT["inbox"] => "fa-solid fa-inbox",
            ACT["read"] => "fa-regular fa-envelope-open",
            ACT["star"] => "fa-regular fa-star",
            ACT["unread"] => "fa-regular fa-envelope",
            ACT["unstar"] => "fa-solid fa-star",
          }.freeze
          REPLY = Components::Mail::FieldError.id_for(:body, Components::Mail::Reply::SCOPE)
          SPAM = Blog::Types::MessageStatus["spam"]
          UNREAD = Blog::Types::MessageStatus["unread"]

          layout nil

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :account, Blog::Types::Instance(ROM::Struct)
          prop :list, Blog::Types::Hash
          prop :labels, Blog::Types::Array.of(Blog::Types::String)
          prop :task, Blog::Types::Integer.optional
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: "#{from} · #{@thread.subject}", return_to: @return_to) do |menu|
              opens(menu)
              menu.separator
              marks(menu)
              menu.separator
              files(menu)
              records(menu)
              menu.separator
              delete(menu)
            end
          end

          private

          def act(menu, act, key = ".#{act}", **)
            menu.post(t(key), action: path(:admin_bulk_mail), icon: ICONS.fetch(act, :trash),
                              fields: { **picked, act: }, **)
          end

          def delete(menu)
            return act(menu, ACT["trash"], ".delete", warn: true, confirm: t(".confirm")) unless @thread.trashed

            act(menu, ACT["delete"], ".delete_forever", warn: true, confirm: t(".confirm_forever"))
          end

          def files(menu)
            Components::Mail::MoveMenu(menu:, fields: picked, except: place)
            Components::Mail::MenuLabels(menu:, thread: @thread, account: @account, labels: @labels, fields: picked)
          end

          def from = @thread.draft ? t(".draft") : @thread.sender.to_s

          def inbox? = @list.key?(:origin)

          def make_task(menu)
            href = "#{thread_path}##{Helpers::MailList.anchor(@thread.id)}"

            menu.link(t(".make_task"), href:, icon: "fa-solid fa-list-check", dialog: "mail-task-#{@thread.id}")
            Components::Mail::TaskDialog(thread: @thread, list: @list, trigger: false)
          end

          def marks(menu)
            act(menu, @thread.status == UNREAD ? ACT["read"] : ACT["unread"])
            act(menu, @thread.starred ? ACT["unstar"] : ACT["star"])
            act(menu, place == ACT["inbox"] ? ACT["archive"] : ACT["inbox"])
            snoozing(menu)
          end

          def opens(menu)
            menu.post(t(".open"), action: path(:admin_open_mail, id: @thread.id), icon: ICONS[ACT["read"]],
                                  fields: shown)
            return if @thread.draft || place == ACT["spam"] || place == ACT["trash"]

            menu.link(t(".reply"), href: "#{thread_path}##{REPLY}", icon: "fa-solid fa-reply")
          end

          def picked = { **shown, "ids[]": @thread.id, **(inbox? ? {} : { return_to: nil }) }

          def place
            return ACT["trash"] if @thread.trashed
            return ACT["spam"] if @thread.status == SPAM

            @thread.archived ? ACT["archive"] : ACT["inbox"]
          end

          def records(menu)
            if @task
              menu.link(t(".open_task", id: @task), href: path(:admin_task, id: @task), icon: "fa-solid fa-list-check")
            else
              make_task(menu)
            end
            return unless @thread.reply_to

            menu.copy(t(".copy_address"), text: @thread.reply_to, copied: t(".copied_address"),
                                          icon: :copy)
          end

          def shown = inbox? ? {} : @list

          def snoozing(menu)
            if @thread.snoozed_until&.>(Time.now)
              menu.post(t(".wake"), action: path(:admin_wake_mail, id: @thread.id), icon: "fa-regular fa-bell",
                                    fields: shown)
            elsif place == ACT["inbox"]
              Components::Inbox::SnoozeMenu(menu:, kind: "message", id: @thread.id)
            end
          end

          def thread_path = path(:admin_mail, **shown, thread: @thread.id)
        end
      end
    end
  end
end
