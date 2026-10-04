# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Index < Action
        include Deps[
          "settings",
          build_social_page: "operations.build_social_page",
          editable_social_post: "social.queries.editable_social_post",
        ]

        def handle(request, response)
          filter = Blog::Types::SocialQueueParam[request.params[:filter]]
          page = requested_page(request, response, settings.page_size[:admin])
          social_page = build_social_page.call(filter:, page:, **editing(request))
          not_found(response) if social_page[:items].past_end?

          response.render(view, **social_page, writing: writing?(request))
        end

        private

        def editing(request)
          params = request.params
          id = Blog::Types::IdParam[params[:edit]]

          { editing: id && editable_social_post.call(id), records: { query: params[:record_q] } }
        end

        def writing?(request) = Blog::Types::Checkbox[request.params[:write]]
      end
    end
  end
end
