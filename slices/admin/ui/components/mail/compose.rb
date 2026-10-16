# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Compose < Component
          ID = "mail-compose"
          SCOPE = "mail-compose"
          TIME = "{time}"
          TO = :to
          MULTIPART = "multipart/form-data"
          OPEN = { compose: Blog::Constants::CHECKED }.freeze
          LABELS = { to: ".to", cc: ".cc", bcc: ".bcc" }.freeze

          prop :senders, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :list, Blog::Types::Hash
          prop :draft, Blog::Types::Hash.optional

          def view_template
            CreateLink(href: path(:admin_mail, **@list, **OPEN), label: t(".compose"), dialog: ID)
            Dialog(id: ID, title: t(".title"), class: "modal mail-compose", static: true, data:) do
              Form(action: path(:admin_send_mail), enctype: MULTIPART, class: "mail-compose-form", data: form_data) do
                fields
              end
            end
          end

          private

          def address(name)
            to = name == TO
            div(class: "mail-head-row", data: (to ? nil : { mail_extra: "" })) do
              label(for: FieldError.id_for(name, SCOPE)) { t(LABELS.fetch(name)) }
              input(**address_attributes(name), autofocus: (true if to))
              reveals if to
              FieldError(field: name, errors:, scope: SCOPE)
            end
          end

          def address_attributes(name)
            own = { class: "mail-head-input", type: "text", name: "mail[#{name}]", value: values[name],
                    autocomplete: "email", required: (true if name == TO) }
            mix(own, FieldError.control_attributes(name, errors, SCOPE))
          end

          def data = { dialog_show: (true if kept) }

          def errors = kept&.fetch(:errors) || Blog::Constants::EMPTY_HASH

          def fields
            HiddenFields(values: @list)
            input(type: "hidden", name: "mail[draft]", value: values[:draft], data: { mail_draft: "" })
            head
            Editor(scope: SCOPE, label: t(".body"), values:, errors:)
            Signature(scope: SCOPE, senders: @senders, from:, on: signature?)
            FieldError(field: :send, errors:, scope: SCOPE)
            foot
          end

          def foot
            div(class: "mail-compose-foot") do
              SendButton()
              Attach(scope: SCOPE)
              span(class: "mail-compose-hint", data: { mail_saved: t(".saved", time: TIME) }) { t(".hint") }
              Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".discard") }
            end
          end

          def form_data = { mail_form: "", mail_draft_url: path(:admin_save_mail_draft) }

          def from = Blog::Types::IdParam[values[:from]] || @senders.first&.id

          def from_field
            div(class: "mail-head-row") do
              label(for: FieldError.id_for(:from, SCOPE)) { t(".from") }
              FromSelect(scope: SCOPE, senders: @senders, from:, errors:, none:, class: "mail-head-input")
              FieldError(field: :from, errors:, scope: SCOPE)
            end
          end

          def head
            div(class: "mail-head") do
              from_field
              %i[to cc bcc].each { address(it) }
              subject
            end
          end

          def kept = (@draft unless @draft&.dig(:values, :thread))

          def none = t(".no_sender")

          def reveals
            span(class: "mail-head-reveal", hidden: true, data: { mail_reveals: "" }) do
              %i[cc bcc].each do |name|
                button(type: "button", data: { mail_reveal: FieldError.id_for(name, SCOPE) }) { t(LABELS.fetch(name)) }
              end
            end
          end

          def signature? = kept.nil? || Blog::Types::Checkbox[values[:signature]]

          def subject
            div(class: "mail-head-row") do
              label(for: FieldError.id_for(:subject, SCOPE)) { t(".subject") }
              input(**mix(
                { class: "mail-head-input mail-head-subject", type: "text", name: "mail[subject]",
                  value: values[:subject], required: true },
                FieldError.control_attributes(:subject, errors, SCOPE),
              ))
              FieldError(field: :subject, errors:, scope: SCOPE)
            end
          end

          def values = kept&.fetch(:values) || Blog::Constants::EMPTY_HASH
        end
      end
    end
  end
end
