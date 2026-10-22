# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Reader < Component
          REASON = "ui.components.inbox.message_item.reasons"
          REASONS = Blog::Types::MailWaitReason.values.to_h { [it, "#{REASON}.#{it}"] }.freeze
          SPAM = Blog::Types::MessageStatus["spam"]

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :list, Blog::Types::Hash
          prop :chip, Blog::Types::Array
          prop :form, Blog::Types::Bool
          prop :own, Blog::Types::String.optional
          prop :task, Blog::Types::Integer.optional, default: nil
          prop :reason, Blog::Types::MailWaitReason.optional, default: nil

          def view_template
            article(id: Helpers::MailList.anchor(@thread.id), class: "mail-reader") do
              meta
              h2(class: "mail-title") { @thread.subject }
              Who(person: @person, sender: @thread.sender, email: @thread.reply_to, form: @form, spam: spam?)
              earlier
              letter(messages.last)
              yield
              ReaderActs(thread: @thread, list: @list, form: @form, task: @task)
            end
          end

          private

          def earlier
            rest = messages[...-1]
            return if rest.empty?

            details(class: "mail-earlier") do
              summary { t(".earlier", count: rest.size, names: rest.map { from(it) }.uniq.join(", ")) }
              rest.each { letter(it) }
            end
          end

          def from(message) = mine?(message) ? t(".you") : (message.from_name || message.reply_to)

          def labels = [*@thread.mail_labels, *@thread.tags].map(&:name).uniq

          def letter(message)
            div(class: ["mail-message", ("me" if mine?(message))]) do
              p(class: "inbox-meta") do
                b { from(message) }
                Moment(at: message.received_at)
              end
              Body(message:)
              Attachments(message:)
            end
          end

          def messages = @thread.mail_messages

          def meta
            p(class: "inbox-meta") do
              Account(chip: @chip)
              span { @thread.reply_to }
              labels.each { |name| span(class: "mail-label") { "##{name}" } }
              Mark(icon: "fa-solid fa-filter", text: t(REASONS.fetch(@reason)), tone: "mail-why") if @reason
              StatusPill(status: :spam) if spam?
            end
          end

          def mine?(message) = !@own.nil? && @own.casecmp?(message.reply_to.to_s)

          def spam? = @thread.status == SPAM
        end
      end
    end
  end
end
