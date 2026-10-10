# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class RejectSuggestions < SuggestionRejectionAction
        REJECTED = "post_form.toasts.rejected"

        include Deps[
          reject_suggestion_edits: "suggestions.operations.reject_suggestion_edits",
          suggestion_queries: "suggestions.repos.suggestion_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          suggestion = suggestion_queries.for_post(id)
          halt 404 unless suggestion

          edit_id = request.params[:edit_id].to_s
          reject(response, suggestion, edit_id)
          response.redirect_to(routes.path(:admin_edit_post, id:, **reviewing(edit_id)))
        end

        private

        def reviewing(edit_id) = edit_id.empty? ? Blog::Constants::EMPTY_HASH : { review: Blog::Constants::CHECKED }
      end
    end
  end
end
