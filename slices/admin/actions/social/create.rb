# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Create < Action
        TOASTS = "social_page.toasts"

        include Deps[
          build_social_page: "operations.build_social_page",
          compose_social_post: "social.operations.compose_social_post",
          describe_social_post: "operations.describe_social_post",
          index_view: "ui.views.social.index",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:social]]

          case compose_social_post.call(params, intent: intent(request))
            in Success[outcome, social_post]
              saved(response, outcome, social_post)
            in Failure[:invalid, errors]
              response.status = 422
              response.render(index_view, **build_social_page.call(params:, errors:))
            else halt 500
          end
        end

        private

        def intent(request) = Blog::Types::SocialIntentParam[request.params[:intent]]

        def saved(response, outcome, social_post)
          toast(response, "#{TOASTS}.#{outcome}", **describe_social_post.call(social_post))
          response.redirect_to(routes.path(:admin_social))
        end
      end
    end
  end
end
