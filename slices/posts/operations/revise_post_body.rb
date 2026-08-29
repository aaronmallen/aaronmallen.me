# frozen_string_literal: true

module Posts
  module Operations
    class RevisePostBody
      include Deps[post_repo: "repos.post_repo"]

      def call(id, body:) = post_repo.update(id, body:)
    end
  end
end
