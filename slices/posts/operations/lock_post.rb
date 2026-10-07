# frozen_string_literal: true

module Posts
  module Operations
    class LockPost
      include Deps[post_mutations: "repos.post_mutations", post_queries: "repos.post_queries"]

      def call(id) = post_mutations.by_id_for_update(id) && post_queries.by_id(id)
    end
  end
end
