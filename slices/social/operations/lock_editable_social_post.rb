# frozen_string_literal: true

module Social
  module Operations
    class LockEditableSocialPost
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(id) = social_post_repo.locked_editable(id)
    end
  end
end
