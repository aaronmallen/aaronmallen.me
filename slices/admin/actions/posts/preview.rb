# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Preview < Action
        include Deps[build_post_preview: "operations.build_post_preview"]

        def handle(request, response)
          response.render(view, **build_post_preview.call(values: Blog::Types::Fields[request.params[:post]]))
        end
      end
    end
  end
end
