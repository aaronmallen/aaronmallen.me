# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Form < Component
          DELETE_FORM = "person-delete"
          EDIT = "edit"
          NEW = "new"
          FIELDS = {
            name: %w[.name .name_placeholder],
            key: %w[.key .key_placeholder],
            mastodon_handle: %w[.mastodon_handle .mastodon_handle_placeholder],
            bluesky_handle: %w[.bluesky_handle .bluesky_handle_placeholder],
          }.freeze
          SEARCHES = { mastodon_handle: "mastodon", bluesky_handle: "bluesky" }.freeze

          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :searchable, Blog::Types::Array.of(Blog::Types::NetworkName)

          def view_template
            render Blog::UI::Components::Form.new(action: form_action, data: { person_form: @person ? EDIT : NEW }) do
              div(class: "form-stack") do
                input_field(:name)
                input_field(:key) { Hint { t(".key_note") } }
                input_field(:mastodon_handle)
                input_field(:bluesky_handle) { Hint { t(".bluesky_handle_note") } }
                FieldError(field: :handles, errors: @errors)
                actions
              end
            end
          end

          private

          def actions
            div(class: "sg-actions") do
              Button(variant: :pri, type: "submit") do
                i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
                span { t(@person ? ".save" : ".add") }
              end
              delete_button if @person
            end
          end

          def delete_button
            Button(variant: :warn, type: "submit", form: DELETE_FORM) do
              i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
              span { t(".delete") }
            end
          end

          def form_action = @person ? path(:admin_update_person, id: @person.id) : path(:admin_create_person)

          def input_field(name)
            label_key, placeholder_key = FIELDS.fetch(name)

            Field(label: t(label_key), name:, errors: @errors, error: FieldError) do |control, field|
              Input(
                **control,
                autocomplete: "off",
                name: "person[#{name}]",
                placeholder: t(placeholder_key),
                value: @values[name],
                data: { person_field: name },
              )
              field.after do
                search(name)
                yield if block_given?
              end
            end
          end

          def search(name)
            network = SEARCHES[name]
            Search(network:) if @searchable.include?(network)
          end
        end
      end
    end
  end
end
