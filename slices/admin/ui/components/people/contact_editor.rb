# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class ContactEditor < Component
          DELETE = "person-delete"

          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :labels, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            Form(action: form_action, class: "contact-form", data: { contact_form: "" }) do
              Top(person: { **@values, name: }, title:, sub: t(@person ? ".sub_edit" : ".sub_new"), **back) do
                actions
              end
              div(class: "g-main") do
                Card(class: "contact-card") { ContactFields(values: @values, errors: @errors) }
                ContactSide(values: @values, labels: @labels)
              end
            end
            delete_form if @person
          end

          private

          def actions
            Button(variant: :warn, type: "submit", form: DELETE) { t(".delete") } if @person
            Button(href: back[:back], variant: :gh) { t(".cancel") }
            Button(variant: :pri, type: "submit") { t(@person ? ".save" : ".add") }
          end

          def back
            return { back: path(:admin_contacts), back_label: t(".contacts") } unless @person

            { back: path(:admin_person, id: @person.id), back_label: Avatar.name_of(@person) }
          end

          def delete_form
            confirm = t(".confirm_delete", name: Avatar.name_of(@person))
            Form(id: DELETE, action: path(:admin_delete_person, id: @person.id), data: { confirm: })
          end

          def form_action = @person ? path(:admin_update_person, id: @person.id) : path(:admin_create_person)

          def name = Helpers::ContactForm.name(@values) || Blog::Types::OptionalText[@values[:company]]

          def title = name || t(@person ? ".unnamed" : ".new_contact")
        end
      end
    end
  end
end
