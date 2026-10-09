# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Editor < Component
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            BackLink(href: path(:admin_people), variant: :gh, small: true, class: "editor-back") { t(".all_people") }

            PageHead(title: @person ? @person.name : t(".new_person"), sub: t(".sub"))
            Card { PersonForm(person: @person, values: @values, errors: @errors) }
          end
        end
      end
    end
  end
end
