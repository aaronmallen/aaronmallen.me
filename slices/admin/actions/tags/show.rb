# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Show < Action
        CAP = 10

        include Deps[tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          kind = Blog::Types::TagKindParam[request.params[:kind]]
          page = kind ? requested_page(request, response) : Blog::Structs::Page.new(number: 1, size: CAP)
          overview = tag_queries.overview(path_param(request, :name), page, kind:)
          not_found(response) unless overview
          not_found(response) if kind && overview.pages.fetch(kind.to_sym).past_end?

          response.render(view, overview:, kind:)
        end
      end
    end
  end
end
