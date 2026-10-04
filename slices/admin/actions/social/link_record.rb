# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["social_post"]

        include RecordLinking
        include Deps[
          build_social_page: "operations.build_social_page",
          editable_social_post: "social.queries.editable_social_post",
          index_view: "ui.views.social.index",
          link_records: "links.operations.link_records",
        ]

        def handle(request, response) = link(request, response)

        private

        def filter(request) = Blog::Types::SocialQueueParam[request.params[:filter]]

        def record_path(request, id) = routes.path(:admin_social, filter: filter(request), edit: id)

        def render_refused(request, response, id, errors)
          editing = editable_social_post.call(id)
          halt 404 unless editing

          page = build_social_page.call(filter: filter(request), editing:, records: records_query(request, errors))
          response.render(index_view, **page)
        end
      end
    end
  end
end
