# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Reply < Component
          ANSWERED = /\Are:/i
          ARCHIVE = { name: "mail[archive]", value: Blog::Constants::CHECKED }.freeze
          SCOPE = "mail-reply"
          SPAM = Blog::Types::MessageStatus["spam"]

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :senders, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :list, Blog::Types::Hash
          prop :form, Blog::Types::Bool
          prop :account, Blog::Types::String
          prop :draft, Blog::Types::Hash.optional

          def view_template
            return if @thread.status == SPAM || @thread.trashed

            details(class: "mail-reply", open: (true if kept)) do
              Button(summary: true, small: true) do
                Icon("fa-solid fa-reply")
                plain t(".reply")
              end
              Form(
                action: path(:admin_send_mail), enctype: Compose::MULTIPART, class: "mail-reply-form",
                data: { mail_form: "" },
              ) { fields }
            end
          end

          private

          def errors = kept&.fetch(:errors) || Blog::Constants::EMPTY_HASH

          def fields
            HiddenFields(values: { **@list, thread: @thread.id })
            HiddenFields(values: hidden)
            head
            Editor(scope: SCOPE, label: t(".body"), values:, errors:)
            Signature(scope: SCOPE, senders: @senders, from:, on: signature?)
            FieldError(field: :send, errors:, scope: SCOPE)
            foot
          end

          def foot
            div(class: "mail-compose-foot") do
              SendButton()
              Button(type: "submit", variant: :gh, small: true, **ARCHIVE) { t(".send_archive") }
              Attach(scope: SCOPE)
            end
          end

          def from
            Blog::Types::IdParam[values[:from]] ||
              @senders.find { it.id == @thread.mail_account_id }&.id || @senders.first&.id
          end

          def from_field
            label(class: "mail-reply-as", for: FieldError.id_for(:from, SCOPE)) { t(".reply_as") }
            FromSelect(scope: SCOPE, senders: @senders, from:, errors:, none: t(".no_sender"), class: "inp auto")
          end

          def head
            div(class: "mail-reply-head") do
              from_field
              hint
              span(class: "mail-reply-to") { t(".to", address: @thread.reply_to) }
            end
            FieldError(field: :from, errors:, scope: SCOPE)
            FieldError(field: :to, errors:, scope: SCOPE)
          end

          def hidden
            subject = @thread.subject.match?(ANSWERED) ? @thread.subject : t(".subject", subject: @thread.subject)

            { "mail[thread]" => @thread.id, "mail[to]" => @thread.reply_to, "mail[subject]" => subject }
          end

          def hint
            return span(class: "mail-reply-hint") { t(".by_email") } if @form
            return if @senders.any? { it.id == @thread.mail_account_id }

            span(class: "mail-reply-hint") { t(".cannot_send", account: @account) }
          end

          def kept = (@draft if Blog::Types::IdParam[@draft&.dig(:values, :thread)] == @thread.id)

          def signature? = kept.nil? || Blog::Types::Checkbox[values[:signature]]

          def values = kept&.fetch(:values) || Blog::Constants::EMPTY_HASH
        end
      end
    end
  end
end
