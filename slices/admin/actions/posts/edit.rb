# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Edit < Action
        KIND = Blog::Types::RecordKind["post"]

        include Deps[
          build_post_editor: "operations.build_post_editor",
          list_record_links: "operations.list_record_links",
          post_queries: "posts.repos.post_queries",
        ]

        def handle(request, response)
          post = post_queries.by_id(record_id(request))
          not_found(response) unless post

          records = list_record_links.call(KIND, post.id, query: request.params[:record_q])
          review = Blog::Types::Checkbox[request.params[:review]]
          response.render(view, **build_post_editor.call(post:, review:), records:)
        end
      end
    end
  end
end
