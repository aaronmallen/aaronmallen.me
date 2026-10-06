# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class Destroy < Action
        KEPT = "social_page.toasts.kept"
        REMOVED = "social_page.toasts.removed"

        include Deps[delete_social_post: "social.operations.delete_social_post"]

        def handle(request, response)
          result = delete_social_post.call(record_id(request))

          case result
          in Failure(:already_posted) then back(request, response, KEPT)
          else settle(response, result, REMOVED, queue_path(request))
          end
        end

        private

        def back(request, response, message)
          toast(response, message)
          response.redirect_to(queue_path(request))
        end

        def filter(request) = Blog::Types::SocialQueueParam[request.params[:filter]]

        def queue_path(request) = routes.path(:admin_social, filter: filter(request))
      end
    end
  end
end
