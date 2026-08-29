# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Index < Action
        include Deps[
          build_social_page: "operations.build_social_page",
          editable_social_post: "social.queries.editable_social_post",
        ]

        def handle(request, response)
          filter = Blog::Types::SocialQueueParam[request.params[:filter]]

          response.render(view, **build_social_page.call(filter:, editing: editing(request)))
        end

        private

        def editing(request)
          id = Blog::Types::IdParam[request.params[:edit]]

          editable_social_post.call(id) if id
        end
      end
    end
  end
end
