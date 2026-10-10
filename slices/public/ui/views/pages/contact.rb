# frozen_string_literal: true

module Public
  module UI
    module Views
      module Pages
        class Contact < View
          BODY_ROWS = 8
          FORM_ID = "contact-form"
          HONEYPOT = :reference
          SENT_ICON = "fa-circle-check"
          STAMP = Operations::IssueContactStamp::FIELD
          THROTTLED_ICON = "fa-hourglass-half"

          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :sent, Blog::Types::Bool, default: false
          prop :throttled, Blog::Types::Bool, default: false
          prop :values, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            head_wording

            div(class: "g even") do
              div(class: "stick") do
                page_head
                ContactInfo()
              end
              div { outcome }
            end
          end

          private

          def actions
            div(class: "f-a") do
              button(class: "f-b", type: "submit") do
                Icon("fa-solid fa-paper-plane")
                plain(t(".send"))
              end
              span(class: "f-n") { t(".note") }
            end
          end

          def body_id = ContactFieldError.id_for(:body)

          def body_row
            row(:body, ".fields.body") do
              textarea(
                **ContactFieldError.control_attributes(:body, @errors),
                class: "f-i",
                maxlength: ::Contact::Types::MAX_BODY,
                name: field_name(:body),
                placeholder: t(".placeholders.body"),
                required: true,
                rows: BODY_ROWS,
              ) { @values[:body] }
              count_line
            end
          end

          def confirmation = panel("f-ok", SENT_ICON, t(".sent.heading"), t(".sent.body"))

          def count_line
            p(class: "f-h", data: { count_for: body_id }, hidden: true) do
              span(data: { count: true })
              plain(t(".count_separator"))
              span(data: { total: true })
            end
          end

          def field_name(name) = "message[#{name}]"

          def fields
            input_row(:reply_to, ".fields.reply_to", ".placeholders.reply_to", type: "email", autocomplete: "email")
            input_row(:subject, ".fields.subject", ".placeholders.subject", maxlength: ::Contact::Types::MAX_SUBJECT)
            body_row
            honeypot
            input(type: "hidden", name: field_name(STAMP), value: @values[STAMP])
          end

          def honeypot
            div(class: "f-hp", aria: { hidden: "true" }) do
              label(for: honeypot_id) { t(".fields.reference") }
              input(
                id: honeypot_id,
                type: "text",
                name: field_name(HONEYPOT),
                tabindex: "-1",
                autocomplete: "off",
              )
            end
          end

          def honeypot_id = ContactFieldError.id_for(HONEYPOT)

          def input_row(name, label_key, placeholder_key, type: "text", **extra)
            row(name, label_key) do
              input(
                **ContactFieldError.control_attributes(name, @errors),
                **extra,
                class: "f-i",
                name: field_name(name),
                placeholder: t(placeholder_key),
                required: true,
                type:,
                value: @values[name],
              )
            end
          end

          def message_form
            form(action: path(:message), class: "form card", id: FORM_ID, method: "post") do
              fields
              actions
            end
          end

          def outcome
            return confirmation if @sent
            return refusal if @throttled

            message_form
          end

          def panel(classes, glyph, heading, line)
            div(class: classes) do
              Icon(["fa-solid", glyph])
              div do
                strong { heading }
                p { line }
              end
            end
          end

          def refusal = panel("f-ok f-wait", THROTTLED_ICON, t(".throttled.heading"), t(".throttled.body"))

          def row(name, label_key, &)
            div(class: "f-row") do
              label(class: "f-l", for: ContactFieldError.id_for(name)) { t(label_key) }
              yield
              ContactFieldError(field: name, errors: @errors)
            end
          end
        end
      end
    end
  end
end
