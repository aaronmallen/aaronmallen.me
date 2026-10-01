# frozen_string_literal: true

module Posts
  module Queries
    class LastDeletedAt
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.last_deleted_at
    end
  end
end
