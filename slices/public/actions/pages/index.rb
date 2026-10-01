# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Index < Action
        POSTS = 10
        PROJECTS = 3

        include Deps[
          latest_published_posts: "posts.queries.latest_published",
          public_project_grid: "projects.queries.public_grid",
        ]

        share_with_caches

        def handle(_request, response)
          response[:posts] = latest_published_posts.call(POSTS)
          response[:projects] = public_project_grid.call(PROJECTS)
        end
      end
    end
  end
end
