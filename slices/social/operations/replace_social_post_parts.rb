# frozen_string_literal: true

module Social
  module Operations
    class ReplaceSocialPostParts
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(id, parts) = social_post_repo.replace_parts(id, parts)
    end
  end
end
