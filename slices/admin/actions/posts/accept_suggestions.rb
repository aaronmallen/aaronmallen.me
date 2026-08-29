# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class AcceptSuggestions < Action
        APPLIED = "post_form.toasts.applied"

        include Deps[
          accept_suggestion_edits: "suggestions.operations.accept_suggestion_edits",
          suggestion_for_post: "suggestions.queries.for_post",
        ]

        def handle(request, response)
          id = record_id(request)
          suggestion = suggestion_for_post.call(id)
          halt 404 unless suggestion

          accept(response, suggestion, request.params[:edit_id].to_s)
          response.redirect_to(routes.path(:admin_edit_post, id:))
        end

        private

        def accept(response, suggestion, edit_id)
          case accept_suggestion_edits.call(suggestion.id, ids: chosen(edit_id))
          in Success(accepted:)
            toast(response, APPLIED, count: accepted.length)
          in Failure(:stale)
            toast(response, APPLIED, count: 0)
          in Failure(:not_found)
            nil
          else halt 500
          end
        end

        def chosen(edit_id) = edit_id.empty? ? nil : Array(Blog::Types::IdParam[edit_id])
      end
    end
  end
end
