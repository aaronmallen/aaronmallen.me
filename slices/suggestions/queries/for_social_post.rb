# frozen_string_literal: true

module Suggestions
  module Queries
    class ForSocialPost
      include Deps[suggestion_repo: "repos.suggestion_repo"]

      def call(social_post_id) = suggestion_repo.for_social_post(social_post_id)
    end
  end
end
