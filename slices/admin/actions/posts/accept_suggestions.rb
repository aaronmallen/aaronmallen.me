# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class AcceptSuggestions < Action
        APPLIED = "post_form.toasts.applied"
        LIVE = "post_form.toasts.live"

        include Deps[
          accept_suggestion_edits: "suggestions.operations.accept_suggestion_edits",
          suggestion_queries: "suggestions.repos.suggestion_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          suggestion = suggestion_queries.for_post(id)
          halt 404 unless suggestion

          edit_id = request.params[:edit_id].to_s
          accept(response, suggestion, edit_id)
          response.redirect_to(routes.path(:admin_edit_post, id:, **reviewing(edit_id)))
        end

        private

        def accept(response, suggestion, edit_id)
          case accept_suggestion_edits.call(suggestion.id, ids: chosen(edit_id))
            in Success(accepted:) then toast(response, APPLIED, count: accepted.length)
            in Failure(:stale) then toast(response, APPLIED, count: 0)
            in Failure(:published) then toast(response, LIVE)
            in Failure(:not_found) then nil
            else halt 500
          end
        end

        def chosen(edit_id) = edit_id.empty? ? nil : Array(Blog::Types::IdParam[edit_id])

        def reviewing(edit_id) = edit_id.empty? ? Blog::Constants::EMPTY_HASH : { review: Blog::Constants::CHECKED }
      end
    end
  end
end
