# frozen_string_literal: true

module Tasks
  module Queries
    class LinkTargets
      LIMIT = 6

      include Deps[task_repo: "repos.task_repo"]

      def call(id, text)
        query = Blog::Types::TrimmedText[text]
        return Blog::Constants::EMPTY_ARRAY if query.empty?

        task_repo.link_targets(id, query, limit: LIMIT)
      end
    end
  end
end
