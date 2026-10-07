# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class AcceptSuggestions < Action
        APPLIED = "social_suggestions.toasts.applied"
        EMPTY_PART = "social_suggestions.toasts.empty_part"
        OVER_LIMIT = "social_suggestions.toasts.over_limit"
        SENT = "social_suggestions.toasts.sent"

        include Deps[
          accept_suggestion_edits: "suggestions.operations.accept_suggestion_edits",
          find_over_limit_network: "operations.find_over_limit_network",
          social_post_queries: "social.repos.social_post_queries",
          suggestion_queries: "suggestions.repos.suggestion_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          social_post = social_post_queries.editable(id)
          halt 404 unless social_post || claimed?(id)

          social_post ? accept(response, social_post, request.params[:edit_id].to_s) : toast(response, SENT)
          response.redirect_to(back_to(request, id))
        end

        private

        def accept(response, social_post, edit_id)
          suggestion = suggestion_queries.for_social_post(social_post.id) || halt(404)

          case accept_suggestion_edits.call(suggestion.id, ids: chosen(edit_id))
            in Success(accepted:, refused:) then applied(response, social_post, accepted, refused)
            in Failure(:already_posted) then toast(response, SENT)
            in Failure(:empty_part, part) then toast(response, EMPTY_PART, part:)
            in Failure(:stale) then toast(response, APPLIED, count: 0)
            in Failure(:not_found) then nil
            else halt 500
          end
        end

        def applied(response, social_post, accepted, refused)
          blocked = refused.first if accepted.empty?
          network = blocked && find_over_limit_network.call(social_post, blocked)
          return toast(response, APPLIED, count: accepted.length) unless network

          toast(response, OVER_LIMIT, limit: network.limit, network: network.label, part: blocked.part_number)
        end

        def back_to(request, id)
          routes.path(:admin_social, filter: Blog::Types::SocialQueueParam[request.params[:filter]], edit: id)
        end

        def chosen(edit_id) = edit_id.empty? ? nil : Array(Blog::Types::IdParam[edit_id])

        def claimed?(id) = social_post_queries.by_id(id)&.deliveries&.any?
      end
    end
  end
end
