# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Search < View
          include Components::People

          layout nil

          prop :results, Blog::Types::Hash, :**

          def view_template = SearchResults(**@results)
        end
      end
    end
  end
end
