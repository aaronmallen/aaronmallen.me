# frozen_string_literal: true

module Social
  module Queries
    class EditableSocialPost
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(id) = social_post_repo.editable(id)
    end
  end
end
