# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["social_post"]

        include Deps[
          build_social_page: "operations.build_social_page",
          index_view: "ui.views.social.index",
          social_post_queries: "social.repos.social_post_queries",
        ]

        private

        def filter(request) = Blog::Types::SocialQueueParam[request.params[:filter]]

        def record_path(request, id) = routes.path(:admin_social, filter: filter(request), edit: id)

        def render_refused(request, response, id, errors)
          editing = social_post_queries.editable(id)
          halt :not_found unless editing

          page = build_social_page.call(filter: filter(request), editing:, records: records_query(request, errors))
          unprocessable(response, index_view, **page)
        end
      end
    end
  end
end
