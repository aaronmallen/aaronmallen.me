# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class RejectSuggestions < Action
        REJECTED = "social_suggestions.toasts.rejected"

        include Deps[
          editable_social_post: "social.queries.editable_social_post",
          reject_edits: "suggestions.operations.reject_edits",
          suggestion_for_social_post: "suggestions.queries.for_social_post",
        ]

        include SuggestionRejection

        def handle(request, response)
          social_post = editable_social_post.call(record_id(request))
          suggestion = social_post && suggestion_for_social_post.call(social_post.id)
          halt 404 unless suggestion

          reject(response, suggestion, request.params[:edit_id].to_s)
          response.redirect_to(back_to(request, social_post.id))
        end

        private

        def back_to(request, id)
          routes.path(:admin_social, filter: Blog::Types::SocialQueueParam[request.params[:filter]], edit: id)
        end
      end
    end
  end
end
