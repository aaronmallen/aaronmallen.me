# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Update < Action
        TOASTS = "social_page.toasts"

        include Deps[
          build_social_page: "operations.build_social_page",
          compose_social_post: "social.operations.compose_social_post",
          describe_social_post: "operations.describe_social_post",
          index_view: "ui.views.social.index",
          social_post_queries: "social.repos.social_post_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:social]]

          case compose_social_post.call(params, intent: intent(request), id:)
            in Success[outcome, social_post] then saved(response, outcome, social_post)
            in Failure(:already_posted) then sent(response)
            in Failure(:not_found) then halt 404
            in Failure[:invalid, errors] then invalid(response, id, params, errors)
            else halt 500
          end
        end

        private

        def intent(request) = Blog::Types::SocialIntentParam[request.params[:intent]]

        def invalid(response, id, params, errors)
          response.status = 422
          response.render(index_view,
                          **build_social_page.call(params:, errors:, editing: social_post_queries.editable(id)))
        end

        def saved(response, outcome, social_post)
          toast(response, "#{TOASTS}.#{outcome}", **describe_social_post.call(social_post))
          response.redirect_to(routes.path(:admin_social))
        end

        def sent(response)
          toast(response, "#{TOASTS}.sent")
          response.redirect_to(routes.path(:admin_social))
        end
      end
    end
  end
end
