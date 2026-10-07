# frozen_string_literal: true

module Social
  module Operations
    class LockEditableSocialPost
      include Deps[
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(id) = social_post_mutations.lock_editable(id) && social_post_queries.editable(id)
    end
  end
end
