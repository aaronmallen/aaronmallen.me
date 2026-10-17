# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class BulkMenu < Action
        FIELDS = %i[status page].freeze
        PUBLIC = Blog::Types::TagScope["public"]

        include Deps[post_queries: "posts.repos.post_queries", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          posts = post_queries.by_ids(picked_ids(request))
          halt :not_found if posts.empty?

          response.render(view, posts:, tags: tag_queries.all_in(PUBLIC), fields: request.params.to_h.slice(*FIELDS))
        end
      end
    end
  end
end
