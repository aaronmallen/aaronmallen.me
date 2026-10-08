# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Directory < Component
          prop :handles, Blog::Types::Hash

          def view_template
            div(hidden: true, data: { social_people: JSON.generate(@handles) })
          end
        end
      end
    end
  end
end
