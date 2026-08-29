# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        module Types
          class IconList < Component
            ID = "task-type-icons"
            NAMES = Blog::Types::TaskTypeIcon.values.freeze

            def view_template
              datalist(id: ID) { NAMES.each { option(value: it) } }
            end
          end
        end
      end
    end
  end
end
