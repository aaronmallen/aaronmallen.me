# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Index < Action
        include Deps[build_projects_page: "operations.build_projects_page"]

        def handle(request, response)
          params = request.params
          filter = Blog::Types::ProjectFilterParam[params[:filter]]
          linking = Blog::Types::IdParam[params[:edit]]

          response.render(view, **build_projects_page.call(filter:, linking:, records: { query: params[:record_q] }))
        end
      end
    end
  end
end
