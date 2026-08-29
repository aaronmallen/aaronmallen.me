# frozen_string_literal: true

module Analytics
  module Queries
    class ViewsByPath
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call = rollup_repo.views_by_path
    end
  end
end
