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
            BackLink(href: people_path, variant: :gh, small: true, class: "editor-back") { t(".all_people") }

            PageHead(title: @person ? @person.name : t(".new_person"), sub: t(".sub"))
            Card(data: { person_editor: true }) { PersonForm(person: @person, values: @values, errors: @errors) }
          end

          private

          def people_path = "#{path(:admin_settings_webmentions)}##{Helpers::WebmentionTab::PEOPLE}"
        end
      end
    end
  end
end
