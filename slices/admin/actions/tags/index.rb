# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Index < Action
        include Deps[build_tags_page: "operations.build_tags_page"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          response.render(view, **build_tags_page.call(scope:, query: request.params[:q]))
        end
      end
    end
  end
end
