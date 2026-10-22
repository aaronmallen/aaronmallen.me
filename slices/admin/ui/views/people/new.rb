# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class New < View
          include Components::People

          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :labels, Blog::Types::Array.of(Blog::Types::String)
          prop :alert, Blog::Types::String.optional, default: nil

          def view_template
            content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
            ContactEditor(person: nil, values: @values, errors: @errors, labels: @labels, alert: @alert)
          end
        end
      end
    end
  end
end
