# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class RunLinkCheck < Action
        BROKEN = Blog::Types::PostFilter["broken"]

        include Deps[queue_link_check_run: "posts.operations.queue_link_check_run"]

        def handle(request, response)
          toast(response, queue_link_check_run.call.success? ? "posts_page.toasts.run_link_check" : QUEUE_UNAVAILABLE)
          response.redirect_to(back_here(request) || routes.path(:admin_posts, status: BROKEN))
        end
      end
    end
  end
end
