# frozen_string_literal: true

module Posts
  module Operations
    class LockPost
      include Deps[post_repo: "repos.post_repo"]

      def call(id) = post_repo.locked_by_id(id)
    end
  end
end
