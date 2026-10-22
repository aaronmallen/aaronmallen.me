# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Edit < View
          include Components::People

          prop :person, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :labels, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
            ContactEditor(person: @person, values: @values, errors: @errors, labels: @labels)
          end
        end
      end
    end
  end
end
