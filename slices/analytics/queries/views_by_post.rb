# frozen_string_literal: true

module Analytics
  module Queries
    class ViewsByPost
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(post_ids) = rollup_repo.views_by_post(post_ids)
    end
  end
end
