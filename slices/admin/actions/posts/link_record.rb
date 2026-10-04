# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["post"]

        include RecordLinking
        include Deps[
          build_post_editor: "operations.build_post_editor",
          edit_view: "ui.views.posts.edit",
          link_records: "links.operations.link_records",
          list_record_links: "operations.list_record_links",
          post_by_id: "posts.queries.by_id",
        ]

        def handle(request, response) = link(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_edit_post, id:)

        def render_refused(request, response, id, errors)
          post = post_by_id.call(id)
          halt 404 unless post

          response.render(edit_view, **build_post_editor.call(post:), records: linked_records(request, id, errors))
        end
      end
    end
  end
end
