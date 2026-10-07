# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Show < Action
        include Deps[tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          summary = tag_queries.summary(path_param(request, :name))
          not_found(response) unless summary

          response.render(view, summary:)
        end
      end
    end
  end
end
