# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Editor < Component
          DELETE_FORM = "person-delete"
          FIELDS = {
            name: %w[.name .name_placeholder],
            key: %w[.key .key_placeholder],
            mastodon_handle: %w[.mastodon_handle .mastodon_handle_placeholder],
            bluesky_handle: %w[.bluesky_handle .bluesky_handle_placeholder],
          }.freeze

          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            a(class: "btn gh sm editor-back", href: path(:admin_people)) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".all_people") }
            end

            PageHead(title: @person ? @person.name : t(".new_person"), sub: t(".sub"))
            Card { form }
            delete_form if @person
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

          def delete_form
            Form(
              id: DELETE_FORM,
              action: path(:admin_delete_person, id: @person.id),
              data: { confirm: t(".confirm_delete", name: @person.name) },
            )
          end

          def field(name, &)
            label_key, placeholder_key = FIELDS.fetch(name)

            Field(label: t(label_key), id: FieldError.id_for(name)) do
              Input(
                **FieldError.control_attributes(name, @errors),
                autocomplete: "off",
                name: "person[#{name}]",
                placeholder: t(placeholder_key),
                value: @values[name],
              )
              FieldError(field: name, errors: @errors)
              yield if block_given?
            end
          end

          def form
            Form(action: form_action) do
              div(class: "form-stack") do
                field(:name)
                field(:key) { Hint { t(".key_note") } }
                field(:mastodon_handle)
                field(:bluesky_handle) { Hint { t(".bluesky_handle_note") } }
                FieldError(field: :handles, errors: @errors)
                actions
              end
            end
          end

          def form_action = @person ? path(:admin_update_person, id: @person.id) : path(:admin_create_person)
        end
      end
    end
  end
end
