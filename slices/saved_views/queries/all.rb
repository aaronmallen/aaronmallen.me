# frozen_string_literal: true

module SavedViews
  module Queries
    class All
      include Deps[saved_view_repo: "repos.saved_view_repo"]

      def call(screen: nil) = saved_view_repo.all(screen:)
    end
  end
end
