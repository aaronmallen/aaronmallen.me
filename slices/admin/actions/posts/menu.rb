# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Menu < Action
        PUBLIC = Blog::Types::TagScope["public"]

        include Deps[post_queries: "posts.repos.post_queries", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          post = post_queries.by_id(record_id(request)) || halt(404)
          list = { status: Blog::Types::PostFilterParam[request.params[:status]], page: page_number(request) }

          response.render(view, post:, list:, tags: tag_queries.all_in(PUBLIC), return_to: back_here(request))
        end
      end
    end
  end
end
