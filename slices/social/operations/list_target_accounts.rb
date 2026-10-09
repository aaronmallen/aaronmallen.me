# frozen_string_literal: true

module Social
  module Operations
    class ListTargetAccounts
      include Deps["services.repos.connection_queries"]

      def call(social_post)
        picked = social_post.connection_ids.to_a
        accounts = social_post.targets.to_a.flat_map { connection_queries.for(it) }

        picked.empty? ? accounts : accounts.select { picked.include?(it.id) }
      end
    end
  end
end
