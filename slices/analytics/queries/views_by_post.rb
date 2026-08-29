# frozen_string_literal: true

module Analytics
  module Queries
    class ViewsByPost
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call = rollup_repo.views_by_post
    end
  end
end
