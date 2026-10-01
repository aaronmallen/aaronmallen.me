# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Editor < Component
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :searchable, Blog::Types::Array.of(Blog::Types::NetworkName)

          def view_template
            a(class: "btn gh sm editor-back", href: path(:admin_people)) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".all_people") }
            end

            PageHead(title: @person ? @person.name : t(".new_person"), sub: t(".sub"))
            Card { render Form.new(person: @person, values: @values, errors: @errors, searchable: @searchable) }
            delete_form if @person
          end

          private

          def delete_form
            render Blog::UI::Components::Form.new(
              id: Form::DELETE_FORM,
              action: path(:admin_delete_person, id: @person.id),
              data: { confirm: t(".confirm_delete", name: @person.name) },
            )
          end
        end
      end
    end
  end
end
