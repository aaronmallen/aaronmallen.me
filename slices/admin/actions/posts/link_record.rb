# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["post"]

        include Deps[
          build_post_editor: "operations.build_post_editor",
          edit_view: "ui.views.posts.edit",
          list_record_links: "operations.list_record_links",
          post_queries: "posts.repos.post_queries",
        ]

        private

        def record_path(_request, id) = routes.path(:admin_edit_post, id:)

        def render_refused(request, response, id, errors)
          post = post_queries.by_id(id)
          halt :not_found unless post

          records = list_record_links.call(KIND, id, **records_query(request, errors))
          unprocessable(response, edit_view, **build_post_editor.call(post:), records:)
        end
      end
    end
  end
end
