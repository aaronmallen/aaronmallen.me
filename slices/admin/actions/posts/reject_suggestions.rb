# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class RejectSuggestions < Action
        REJECTED = "post_form.toasts.rejected"

        include Deps[
          reject_suggestion_edits: "suggestions.operations.reject_suggestion_edits",
          suggestion_for_post: "suggestions.queries.for_post",
        ]

        include SuggestionRejection

        def handle(request, response)
          id = record_id(request)
          suggestion = suggestion_for_post.call(id)
          halt 404 unless suggestion

          reject(response, suggestion, request.params[:edit_id].to_s)
          response.redirect_to(routes.path(:admin_edit_post, id:))
        end
      end
    end
  end
end
