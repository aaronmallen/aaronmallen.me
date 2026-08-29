# frozen_string_literal: true

module Record
  module Queries
    class CommitById
      include Deps[commit_repo: "repos.commit_repo"]

      def call(id) = commit_repo.by_id(id)
    end
  end
end
