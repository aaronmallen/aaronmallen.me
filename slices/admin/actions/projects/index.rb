# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Index < Action
        include Deps[build_projects_page: "operations.build_projects_page"]

        def handle(request, response)
          filter = Blog::Types::ProjectFilterParam[request.params[:filter]]

          response.render(view, **build_projects_page.call(filter:))
        end
      end
    end
  end
end
