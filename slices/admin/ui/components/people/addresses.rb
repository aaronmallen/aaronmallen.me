# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Addresses < Component
          FIELDS = {
            street: true, extended: true, city: false, region: false, postal_code: false, country: false,
          }.freeze
          LABELS = FIELDS.keys.to_h { [it, ".#{it}"] }.freeze
          TYPES = %w[home work other].freeze

          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            div(class: "field contact-entries", data: { contact_entries: "" }) do
              span(class: "f") { t(".label") }
              @rows.each { entry(it) }
              template(data: { contact_template: "" }) { entry(Blog::Constants::EMPTY_HASH) }
              button(type: "button", class: "contact-add", data: { contact_add: "" }) { t(".add") }
            end
          end

          private

          def entry(row)
            div(class: "contact-address-entry", data: { contact_entry: "" }) do
              FIELDS.each { |key, wide| input_for(row, key, wide) }
              div(class: "contact-address-foot") { foot(row[:type]) }
            end
          end

          def field(key) = "person[addresses][][#{key}]"

          def foot(type)
            Select(
              name: field(:type), options: (TYPES | [type].compact).to_h { [it, it] }, selected: type,
              aria: { label: t(".type") },
            )
            button(type: "button", class: "contact-remove-text", data: { contact_remove: "" }) { t(".remove") }
          end

          def input_for(row, key, wide)
            text = t(LABELS.fetch(key))

            Input(class: ("wide" if wide), name: field(key), value: row[key], placeholder: text, aria: { label: text })
          end
        end
      end
    end
  end
end
