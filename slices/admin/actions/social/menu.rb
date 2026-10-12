# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Menu < Action
        include Deps[social_post_queries: "social.repos.social_post_queries"]

        def handle(request, response)
          social_post = social_post_queries.by_id(record_id(request)) || halt(404)
          filter = Blog::Types::SocialQueueParam[request.params[:filter]]

          response.render(view, social_post:, filter:, return_to: back_here(request))
        end
      end
    end
  end
end
