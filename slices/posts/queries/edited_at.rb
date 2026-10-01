# frozen_string_literal: true

module Posts
  module Queries
    class EditedAt
      include Deps[post_edit_repo: "repos.post_edit_repo"]

      def call(post_ids) = post_edit_repo.edited_at(post_ids)
    end
  end
end
