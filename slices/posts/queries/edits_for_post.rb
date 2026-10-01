# frozen_string_literal: true

module Posts
  module Queries
    class EditsForPost
      include Deps[post_edit_repo: "repos.post_edit_repo"]

      def call(post_id) = post_edit_repo.for_post(post_id)
    end
  end
end
