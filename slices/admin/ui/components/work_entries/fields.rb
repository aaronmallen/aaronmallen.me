# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class Fields < Component
          ROWS = 3
          WRITING = /\S/

          VALUES = Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)

          prop :values, VALUES, default: Blog::Constants::EMPTY_HASH
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            render Blog::UI::Components::Form.new(action: path(:admin_create_work_entry), data: { work_form: "" }) do
              div(class: "form-stack") { fields }
            end
          end

          private

          def add_button
            Button(variant: :pri, type: "submit", disabled: !ready?, data: { work_add: "" }) do
              i(class: "fa-solid fa-plus", aria: { hidden: "true" })
              span { t(".add") }
            end
          end

          def blurb_field
            field(:blurb, ".blurb") do
              Textarea(
                **FieldError.control_attributes(:blurb, @errors),
                name: "work_entry[blurb]",
                rows: ROWS,
                placeholder: t(".blurb_placeholder"),
                value: @values[:blurb],
              )
            end
          end

          def field(name, label_key, &)
            Field(label: t(label_key), id: FieldError.id_for(name)) do
              yield
              FieldError(field: name, errors: @errors)
            end
          end

          def fields
            input_field(:org, ".org", ".org_placeholder", data: { work_org: "" })
            input_field(:role, ".role", ".role_placeholder", data: { work_role: "" })
            Grid(columns: 2) { years }
            blurb_field
            Hint { t(".current_note") }
            add_button
          end

          def filled?(name) = @values[name].to_s.match?(WRITING)

          def input_field(name, label_key, placeholder_key, **extra)
            field(name, label_key) do
              Input(
                **FieldError.control_attributes(name, @errors),
                **extra,
                name: "work_entry[#{name}]",
                value: @values[name],
                placeholder: t(placeholder_key),
              )
            end
          end

          def ready? = filled?(:org) && filled?(:role)

          def years
            input_field(:from_year, ".from", ".from_placeholder", inputmode: "numeric")
            input_field(:to_year, ".to", ".to_placeholder", inputmode: "numeric")
          end
        end
      end
    end
  end
end
