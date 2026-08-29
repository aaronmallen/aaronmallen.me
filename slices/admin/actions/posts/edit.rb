# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Edit < Action
        include Deps[build_post_editor: "operations.build_post_editor", post_by_id: "posts.queries.by_id"]

        def handle(request, response)
          post = post_by_id.call(record_id(request))
          not_found(response) unless post

          response.render(view, **build_post_editor.call(post:))
        end
      end
    end
  end
end
