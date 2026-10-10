# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class BackLink < Component
          FROM_TODAY = Blog::Types::TaskOrigin["today"]

          prop :origin, Blog::Types::TaskOrigin
          prop :filter, Blog::Types::String.optional, default: nil
          prop :attributes, Blog::Types::Hash, :**

          def view_template
            Components::BackLink(href:, **@attributes) { t(today? ? ".today" : ".tasks") }
          end

          private

          def href = today? ? path(:admin_root) : path(:admin_tasks, **{ filter: @filter }.compact)

          def today? = @origin == FROM_TODAY
        end
      end
    end
  end
end
