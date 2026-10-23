# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Show < Action
        CAP = 10

        include Deps[tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          project = project(request, response)
          kind = Blog::Types::TagKindParam[request.params[:kind]]
          overview = overview(request, response, kind, project)

          response.render(view, overview:, kind:, project:)
        end

        private

        def overview(request, response, kind, project)
          page = kind ? requested_page(request, response) : Blog::Structs::Page.new(number: 1, size: CAP)
          found = tag_queries.overview(path_param(request, :name), page, kind:, project_id: project&.id)
          not_found(response) unless found
          not_found(response) if kind && found.pages.fetch(kind.to_sym) { not_found(response) }.past_end?

          found
        end

        def project(_request, _response) = nil
      end
    end
  end
end
