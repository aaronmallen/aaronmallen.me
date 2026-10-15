# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class ReaderActs < Component
          ACT = Blog::Types::MessageBulkAction
          BACK = "fa-solid fa-rotate-left"
          GMAIL = "https://mail.google.com"
          ICONS = {
            ".archive" => ["fa-solid fa-box-archive"], ".mark_read" => ["fa-regular fa-envelope-open", :gh],
            ".mark_unread" => ["fa-regular fa-envelope", :gh], ".not_spam" => [BACK], ".restore" => [BACK],
            ".spam" => ["fa-solid fa-ban", :warn], ".star" => ["fa-regular fa-star", :gh],
            ".unstar" => ["fa-solid fa-star", :gh],
          }.freeze
          EDIT = "fa-regular fa-pen-to-square"
          OUT = "fa-solid fa-arrow-up-right-from-square"
          READ = Blog::Types::MessageStatus["read"]
          SPAM = Blog::Types::MessageStatus["spam"]
          TRASH = "fa-regular fa-trash-can"
          UNREAD = Blog::Types::MessageStatus["unread"]

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :list, Blog::Types::Hash
          prop :form, Blog::Types::Bool
          prop :task, Blog::Types::Integer.optional, default: nil

          def view_template
            div(class: "mail-acts") { gone? ? gone_acts : acts }
          end

          private

          def acts
            edit if @thread.draft
            change(ACT["archive"], ".archive") unless @thread.archived
            snoozed? ? wake : snooze
            TaskButton(thread: @thread, task: @task, list: @list)
            star
            read
            div(class: "mail-acts-far") { @form ? form_acts : gmail }
          end

          def change(act, label_key)
            icon, variant = ICONS.fetch(label_key)
            Form(action: path(:admin_change_mail, id: @thread.id, act:), data: { morph: true }) do
              HiddenFields(values: @list)
              Button(type: "submit", variant:, small: true, icon:) { t(label_key) }
            end
          end

          def delete(label_key, confirm_key)
            Form(action: path(:admin_delete_mail, id: @thread.id), data: { morph: true }) do
              HiddenFields(values: @list)
              Button(type: "submit", variant: :warn, small: true, icon: TRASH, data: { confirm: t(confirm_key) }) do
                t(label_key)
              end
            end
          end

          def edit
            href = path(:admin_mail, **@list, thread: @thread.id, resume: Blog::Constants::CHECKED)
            Button(href:, small: true, icon: EDIT) { t(".edit_draft") }
          end

          def form_acts
            change(SPAM, ".spam")
            delete(".delete", ".confirm_delete")
          end

          def gmail
            Button(variant: :gh, small: true, icon: OUT, href: GMAIL, target: "_blank", rel: "noopener") { t(".gmail") }
          end

          def gone? = spam? || @thread.trashed

          def gone_acts
            spam? ? change(READ, ".not_spam") : change(ACT["inbox"], ".restore")
            div(class: "mail-acts-far") { delete(".delete_forever", ".confirm_delete_forever") }
          end

          def read = @thread.status == UNREAD ? change(READ, ".mark_read") : change(UNREAD, ".mark_unread")

          def snooze
            Inbox::Snooze(kind: "message", id: @thread.id, action: path(:admin_snooze_mail, id: @thread.id)) do
              HiddenFields(values: @list)
            end
          end

          def snoozed? = @thread.snoozed_until&.>(Time.now)

          def spam? = @thread.status == SPAM

          def star = @thread.starred ? change(ACT["unstar"], ".unstar") : change(ACT["star"], ".star")

          def wake
            Form(action: path(:admin_wake_mail, id: @thread.id), data: { morph: true }) do
              HiddenFields(values: @list)
              Button(type: "submit", small: true, icon: "fa-regular fa-clock") { t(".wake") }
            end
          end
        end
      end
    end
  end
end
