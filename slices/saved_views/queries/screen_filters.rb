# frozen_string_literal: true

module SavedViews
  module Queries
    class ScreenFilters
      def call(screen) = Filters.names(screen)
    end
  end
end
