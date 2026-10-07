# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class RejectSuggestions < Action
        REJECTED = "social_suggestions.toasts.rejected"

        include Deps[
          reject_suggestion_edits: "suggestions.operations.reject_suggestion_edits",
          suggestion_queries: "suggestions.repos.suggestion_queries",
        ]

        include SuggestionRejection

        def handle(request, response)
          id = record_id(request)
          suggestion = suggestion_queries.for_social_post(id)
          halt 404 unless suggestion

          reject(response, suggestion, request.params[:edit_id].to_s)
          response.redirect_to(back_to(request, id))
        end

        private

        def back_to(request, id)
          routes.path(:admin_social, filter: Blog::Types::SocialQueueParam[request.params[:filter]], edit: id)
        end
      end
    end
  end
end
