# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class EntryForm < Component
          prop :values, Fields::VALUES
          prop :errors, Blog::Types::Hash

          def view_template
            Card(title: t(".title")) { Fields(values: @values, errors: @errors) }
          end
        end
      end
    end
  end
end
