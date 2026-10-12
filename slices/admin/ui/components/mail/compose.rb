# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Compose < Component
          ID = "mail-compose"
          SCOPE = "mail-compose"
          TITLE_ID = "mail-compose-title"
          TO = :to
          OPEN = { compose: Blog::Constants::CHECKED }.freeze
          LABELS = { to: ".to", cc: ".cc", bcc: ".bcc" }.freeze

          prop :senders, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :list, Blog::Types::Hash
          prop :draft, Blog::Types::Hash.optional

          def view_template
            CreateLink(href: path(:admin_mail, **@list, **OPEN), label: t(".compose"), dialog: ID)
            Dialog(id: ID, title_id: TITLE_ID, title: t(".title"), class: "modal mail-compose", data:) do
              Form(action: path(:admin_send_mail), class: "mail-compose-form", data: { mail_form: "" }) { fields }
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

          def data = { dialog: "static", dialog_show: (true if kept) }

          def errors = kept&.fetch(:errors) || Blog::Constants::EMPTY_HASH

          def fields
            HiddenFields(values: @list)
            head
            Editor(scope: SCOPE, label: t(".body"), values:, errors:)
            Signature(scope: SCOPE, senders: @senders, from:, on: signature?)
            FieldError(field: :send, errors:, scope: SCOPE)
            foot
          end

          def foot
            div(class: "mail-compose-foot") do
              SendButton()
              span(class: "mail-compose-hint") { t(".hint") }
              Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".discard") }
            end
          end

          def from = Blog::Types::IdParam[values[:from]] || @senders.first&.id

          def from_attributes
            options = @senders.to_h { [it.id.to_s, it.address] }

            { name: "mail[from]", options:, selected: from&.to_s, class: "mail-head-input", data: { mail_from: "" } }
          end

          def from_field
            div(class: "mail-head-row") do
              label(for: FieldError.id_for(:from, SCOPE)) { t(".from") }
              if @senders.empty?
                span(class: "mail-head-none") { t(".no_sender") }
              else
                Select(**FieldError.control_attributes(:from, errors, SCOPE), **from_attributes)
              end
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
