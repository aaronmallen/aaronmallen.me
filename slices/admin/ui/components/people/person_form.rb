# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class PersonForm < Component
          SCOPE = "person"
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
          prop :scope, Blog::Types::String, default: SCOPE

          def self.delete_form(scope) = "#{scope}-delete"

          def view_template
            Form(action: form_action, data: { person_form: @person ? EDIT : NEW }) do
              div(class: "form-stack") { fields }
            end
            delete_form if @person
          end

          private

          def actions
            div(class: "sg-actions") do
              Button(variant: :pri, type: "submit", icon: "fa-regular fa-floppy-disk") { t(@person ? ".save" : ".add") }
              delete_button if @person
            end
          end

          def delete_button
            Button(variant: :warn, type: "submit", form: delete_form_id, icon: "fa-regular fa-trash-can") do
              t(".delete")
            end
          end

          def delete_form
            Form(
              id: delete_form_id,
              action: path(:admin_delete_person, id: @person.id),
              data: { confirm: t(".confirm_delete", name: @person.name) },
            )
          end

          def delete_form_id = self.class.delete_form(@scope)

          def fields
            input_field(:name)
            input_field(:key) { Hint { t(".key_note") } }
            input_field(:mastodon_handle)
            input_field(:bluesky_handle) { Hint { t(".bluesky_handle_note") } }
            FieldError(field: :handles, errors: @errors, scope: @scope)
            actions
          end

          def form_action = @person ? path(:admin_update_person, id: @person.id) : path(:admin_create_person)

          def input_field(name)
            label_key, placeholder_key = FIELDS.fetch(name)

            Field(label: t(label_key), name:, errors: @errors, error: FieldError, scope: @scope) do |control, field|
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
            Search(network:, scope: @scope) if @searchable.include?(network)
          end
        end
      end
    end
  end
end
