# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class ReaderActs < Component
          ACT = Blog::Types::MessageBulkAction
          GMAIL = "https://mail.google.com"
          VARIANTS = {
            ".mark_read" => :gh, ".mark_unread" => :gh, ".spam" => :warn, ".star" => :gh, ".unstar" => :gh,
          }.freeze
          READ = Blog::Types::MessageStatus["read"]
          SPAM = Blog::Types::MessageStatus["spam"]
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
            div(class: "mail-acts-far") { @form ? form_acts : gmail_acts }
          end

          def change(act, label_key, icon: ActIcon[act])
            variant = VARIANTS[label_key]
            ButtonForm(
              action: path(:admin_change_mail, id: @thread.id, act:), label: t(label_key), variant:, icon:, morph: true,
              hidden: @list,
            )
          end

          def delete(label_key, confirm_key)
            ButtonForm(
              action: path(:admin_delete_mail, id: @thread.id), label: t(label_key), variant: :warn, icon: :trash,
              morph: true, hidden: @list, button: { data: { confirm: t(confirm_key) } },
            )
          end

          def edit
            href = path(:admin_mail, **@list, thread: @thread.id, resume: Blog::Constants::CHECKED)
            Button(href:, small: true, icon: :edit) { t(".edit_draft") }
          end

          def form_acts
            change(SPAM, ".spam")
            delete(".delete", ".confirm_delete")
          end

          def gmail
            Button(variant: :gh, small: true, icon: :outbound, href: GMAIL, target: "_blank", rel: "noopener") do
              t(".gmail")
            end
          end

          def gmail_acts
            trash
            gmail
          end

          def gone? = spam? || @thread.trashed

          def gone_acts
            spam? ? change(READ, ".not_spam", icon: :restore) : change(ACT["inbox"], ".restore", icon: :restore)
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

          def trash
            ButtonForm(
              action: path(:admin_bulk_mail), label: t(".trash"), variant: :warn, icon: :trash, morph: true,
              hidden: { **@list, "ids[]": @thread.id, act: ACT["trash"] },
            )
          end

          def wake
            ButtonForm(
              action: path(:admin_wake_mail, id: @thread.id), label: t(".wake"), icon: "fa-regular fa-clock",
              morph: true, hidden: @list,
            )
          end
        end
      end
    end
  end
end
