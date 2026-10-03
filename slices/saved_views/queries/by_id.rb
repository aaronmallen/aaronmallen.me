# frozen_string_literal: true

module SavedViews
  module Queries
    class ById
      include Deps[saved_view_repo: "repos.saved_view_repo"]

      def call(id) = saved_view_repo.by_id(id)
    end
  end
end
