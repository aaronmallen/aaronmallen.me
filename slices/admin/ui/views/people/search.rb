# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Search < View
          include Components::People

          layout nil

          def initialize(**results)
            super()
            @results = results
          end

          def view_template = SearchResults(**@results)
        end
      end
    end
  end
end
