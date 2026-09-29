# frozen_string_literal: true

module Public
  module Actions
    module Tags
      class Show < Action
        MOVED_PERMANENTLY = 301

        include Deps[
          "settings",
          public_projects_by_tag: "projects.queries.public_by_tag",
          published_page_by_tag: "posts.queries.published_page_by_tag",
        ]

        def handle(request, response)
          tag = Blog::Types::Normalized::Tag.call(path_param(request, :tag)) { not_found(response) }
          page = requested_page(request, response, settings.page_size[:public])
          redirect_to_own_path(request, response, tag, page)
          expose_listing(response, tag, page)
        end

        private

        def expose_listing(response, tag, page)
          posts = published_page_by_tag.call(tag, page)
          projects = page.number == 1 ? public_projects_by_tag.call(tag) : []
          not_found(response) if posts.rows.empty? && projects.empty?

          response[:tag] = tag
          response[:posts] = posts
          response[:projects] = projects
        end

        def redirect_to_own_path(request, response, tag, page)
          return if request.path == routes.path(:tag, tag:)

          response.redirect_to(routes.path(:tag, tag:, **page.query), status: MOVED_PERMANENTLY)
        end
      end
    end
  end
end
