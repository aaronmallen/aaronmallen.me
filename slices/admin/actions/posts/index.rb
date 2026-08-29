# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Index < Action
        include Deps[build_posts_page: "operations.build_posts_page"]

        def handle(request, response)
          response.render(view, **build_posts_page.call(filter: request.params[:status]))
        end
      end
    end
  end
end
