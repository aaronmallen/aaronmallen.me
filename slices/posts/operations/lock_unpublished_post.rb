# frozen_string_literal: true

module Posts
  module Operations
    class LockUnpublishedPost < Blog::Operation
      include Deps[post_mutations: "repos.post_mutations", post_queries: "repos.post_queries"]

      def call(id)
        post = post_mutations.by_id_for_update(id) && post_queries.by_id(id)

        step(found(post).bind { it.published? ? Failure(:published) : Success(it) })
      end
    end
  end
end
