# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Destroy < Action
        DELETED = "post_form.toasts.deleted"

        include Deps[delete_post: "posts.operations.delete_post"]

        def handle(request, response)
          case delete_post.call(record_id(request))
          in Success(_)
            toast(response, DELETED)
            response.redirect_to(routes.path(:admin_posts))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
