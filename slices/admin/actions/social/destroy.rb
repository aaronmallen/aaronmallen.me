# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Destroy < Action
        KEPT = "social_page.toasts.kept"
        REMOVED = "social_page.toasts.removed"

        include Deps[delete_social_post: "social.operations.delete_social_post"]

        def handle(request, response)
          case delete_social_post.call(record_id(request))
          in Success(_) then back(request, response, REMOVED)
          in Failure(:already_posted) then back(request, response, KEPT)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        private

        def back(request, response, message)
          toast(response, message)
          response.redirect_to(routes.path(:admin_social, filter: filter(request)))
        end

        def filter(request) = Blog::Types::SocialQueueParam[request.params[:filter]]
      end
    end
  end
end
