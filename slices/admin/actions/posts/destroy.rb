# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Destroy < Action
        DELETED = "post_form.toasts.deleted"

        include Deps[delete_post: "posts.operations.delete_post"]

        def handle(request, response)
          settle(response, delete_post.call(record_id(request)), DELETED, routes.path(:admin_posts))
        end
      end
    end
  end
end
