# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class CheckLinks < Action
        TOASTS = "posts_page.toasts.check_links"

        include Deps[queue_link_check: "posts.operations.queue_link_check"]

        def handle(request, response)
          id = record_id(request)
          url = Blog::Types::OptionalText[request.params[:url]]

          toast(response, "#{TOASTS}.#{queue(id, url)}")
          response.redirect_to(back_here(request) || routes.path(:admin_edit_post, id:, links: Blog::Constants::CHECKED))
        end

        private

        def queue(id, url)
          case queue_link_check.call(id, url)
            in Success then url ? :one : :all
            in Failure(:not_found) then :not_published
          end
        end
      end
    end
  end
end
