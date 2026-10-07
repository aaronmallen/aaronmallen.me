# frozen_string_literal: true

module Public
  module Actions
    module Tags
      class Show < Action
        include Deps[
          "settings",
          post_queries: "posts.repos.post_queries",
          project_queries: "projects.repos.project_queries",
        ]

        share_with_caches

        def handle(request, response)
          tag = Blog::Types::Normalized::Tag.call(path_param(request, :tag)) { not_found(response) }
          page = requested_page(request, response, settings.page_size[:public])
          redirect_to_own_path(request, response, :tag, page, tag:)
          expose_listing(response, tag, page)
        end

        private

        def expose_listing(response, tag, page)
          posts = post_queries.published_page_by_tag(tag, page)
          projects = page.number == 1 ? project_queries.public_by_tag(tag) : []
          not_found(response) if posts.rows.empty? && projects.empty?

          response[:tag] = tag
          response[:posts] = posts
          response[:projects] = projects
        end
      end
    end
  end
end
