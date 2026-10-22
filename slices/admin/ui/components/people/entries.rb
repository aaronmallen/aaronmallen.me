# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Entries < Component
          CUSTOM = :custom_fields
          DATE = "date"
          PARTIAL = "-"

          prop :list, Blog::Types::Symbol
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)
          prop :types, Blog::Types::Array.of(Blog::Types::String), default: -> { Blog::Constants::EMPTY_ARRAY }
          prop :type, Blog::Types::String, default: "text"
          prop :placeholder, Blog::Types::String.optional, default: nil
          prop :errors, Blog::Types::Hash

          def view_template
            div(class: "field contact-entries", data: { contact_entries: "" }) do
              span(class: "f") { label }
              @rows.each { entry(it) }
              template(data: { contact_template: "" }) { entry(Blog::Constants::EMPTY_HASH) }
              button(type: "button", class: "contact-add", data: { contact_add: "" }) { t([".add", @list].join(".")) }
              FieldError(field: @list, errors: @errors)
            end
          end

          private

          def custom(row)
            Input(name: field(:key), value: row[:key], placeholder: t(".custom_key"), aria: { label: t(".custom_key") })
            Input(name: field(:value), value: row[:value], placeholder: t(".custom_value"),
                  aria: { label: t(".custom_value") })
          end

          def entry(row)
            div(class: ["contact-entry", ("two" if @list == CUSTOM)], data: { contact_entry: "" }) do
              @list == CUSTOM ? custom(row) : typed(row)
              button(
                type: "button", class: "contact-remove", aria: { label: t([".remove", @list].join(".")) },
                data: { contact_remove: "" },
              ) { Icon(:close) }
            end
          end

          def field(key) = "person[#{@list}][][#{key}]"

          def input_type(value) = @type == DATE && value.start_with?(PARTIAL) ? "text" : @type

          def label = t([".labels", @list].join("."))

          def typed(row)
            value = row[:value].to_s
            type = row[:type]

            Input(type: input_type(value), name: field(:value), value:, placeholder: @placeholder, aria: { label: })
            Select(
              name: field(:type), options: (@types | [type].compact).to_h { [it, it] }, selected: type,
              aria: { label: t(".type", list: label) },
            )
          end
        end
      end
    end
  end
end
