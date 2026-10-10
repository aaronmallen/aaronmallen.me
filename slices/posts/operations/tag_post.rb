# frozen_string_literal: true

module Posts
  module Operations
    class TagPost < Blog::Operation
      include Deps[post_mutations: "repos.post_mutations", post_queries: "repos.post_queries"]

      def call(id, name)
        transaction do
          step find(id)
          post_mutations.add_tag(id, name)
          post_queries.by_id(id)
        end
      end

      private

      def find(id) = found(post_mutations.by_id_for_update(id) && id)
    end
  end
end
