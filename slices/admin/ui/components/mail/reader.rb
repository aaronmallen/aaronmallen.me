# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Reader < Component
          GMAIL = "https://mail.google.com"
          READ = Blog::Types::MessageStatus["read"]
          SPAM = Blog::Types::MessageStatus["spam"]
          UNREAD = Blog::Types::MessageStatus["unread"]

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :list, Blog::Types::Hash
          prop :chip, Blog::Types::Array
          prop :form, Blog::Types::Bool
          prop :own, Blog::Types::String.optional

          def view_template
            article(id: Helpers::MailList.anchor(@thread.id), class: "mail-reader") do
              meta
              h2(class: "mail-title") { @thread.subject }
              Who(person: @person, sender: @thread.sender, form: @form, spam: spam?)
              earlier
              letter(messages.last)
              div(class: "mail-acts") { spam? ? spam_acts : acts }
            end
          end

          private

          def acts
            @thread.status == UNREAD ? mark(READ, ".mark_read") : mark(UNREAD, ".mark_unread")
            snoozed? ? wake : snooze
            div(class: "mail-acts-far") { @form ? form_acts : gmail }
          end

          def delete(label_key, confirm_key)
            Form(action: path(:admin_delete_mail, id: @thread.id), data: { morph: true }) do
              HiddenFields(values: @list)
              Button(type: "submit", variant: :warn, small: true, data: { confirm: t(confirm_key) }) { t(label_key) }
            end
          end

          def earlier
            rest = messages[...-1]
            return if rest.empty?

            details(class: "mail-earlier") do
              summary { t(".earlier", count: rest.size, names: rest.map { from(it) }.uniq.join(", ")) }
              rest.each { letter(it) }
            end
          end

          def form_acts
            mark(SPAM, ".spam", variant: :warn)
            delete(".delete", ".confirm_delete")
          end

          def from(message) = mine?(message) ? t(".you") : (message.from_name || message.reply_to)

          def gmail = Button(variant: :gh, small: true, href: GMAIL, target: "_blank", rel: "noopener") { t(".gmail") }

          def labels = [*@thread.mail_labels, *@thread.tags].map(&:name).uniq

          def letter(message)
            div(class: ["mail-message", ("me" if mine?(message))]) do
              p(class: "inbox-meta") do
                b { from(message) }
                Moment(at: message.received_at)
              end
              p(class: "msg-body mail-message-body") { message.body }
            end
          end

          def mark(status, label_key, variant: nil)
            Form(action: path(:admin_mark_mail, id: @thread.id, status:), data: { morph: true }) do
              HiddenFields(values: @list)
              Button(type: "submit", variant:, small: true) { t(label_key) }
            end
          end

          def messages = @thread.mail_messages

          def meta
            p(class: "inbox-meta") do
              Account(chip: @chip)
              span { @thread.reply_to }
              labels.each { |name| span(class: "mail-label") { "##{name}" } }
              StatusPill(status: :spam) if spam?
            end
          end

          def mine?(message) = !@own.nil? && @own.casecmp?(message.reply_to.to_s)

          def snooze
            Inbox::Snooze(kind: "message", id: @thread.id, action: path(:admin_snooze_mail, id: @thread.id)) do
              HiddenFields(values: @list)
            end
          end

          def snoozed? = @thread.snoozed_until&.>(Time.now)

          def spam? = @thread.status == SPAM

          def spam_acts
            mark(READ, ".not_spam")
            div(class: "mail-acts-far") { delete(".delete_forever", ".confirm_delete_forever") if @form }
          end

          def wake
            Form(action: path(:admin_wake_mail, id: @thread.id), data: { morph: true }) do
              HiddenFields(values: @list)
              Button(type: "submit", small: true) { t(".wake") }
            end
          end
        end
      end
    end
  end
end
