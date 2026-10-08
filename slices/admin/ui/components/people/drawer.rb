# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Drawer < Component
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :searchable, Blog::Types::Array.of(Blog::Types::NetworkName)

          def self.id_for(person) = person ? "person-#{person.id}" : "person-new"

          def view_template
            Dialog(id: "#{scope}-drawer", title_id: "#{scope}-title", title:, data: { dialog: true }) do
              Hint { t("ui.components.people.editor.sub") }
              PersonForm(person: @person, values: @values, errors: @errors, searchable: @searchable, scope:)
            end
          end

          private

          def scope = self.class.id_for(@person)

          def title = @person ? @person.name : t("ui.components.people.editor.new_person")
        end
      end
    end
  end
end
