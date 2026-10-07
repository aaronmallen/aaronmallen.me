# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Index < Action
        POSTS = 10
        PROJECTS = 3

        include Deps[
          post_queries: "posts.repos.post_queries",
          project_queries: "projects.repos.project_queries",
        ]

        share_with_caches

        def handle(_request, response)
          response[:posts] = post_queries.published(POSTS)
          response[:projects] = project_queries.public_grid(PROJECTS)
        end
      end
    end
  end
end
