# frozen_string_literal: true

module Public
  module Actions
    module Tags
      class Show < Action
        MOVED_PERMANENTLY = 301

        include Deps[
          public_projects_by_tag: "projects.queries.public_by_tag",
          published_posts_by_tag: "posts.queries.published_by_tag",
        ]

        def handle(request, response)
          tag = normalized_tag(request, response)
          posts = published_posts_by_tag.call(tag)
          projects = public_projects_by_tag.call(tag)
          not_found(response) if posts.empty? && projects.empty?

          response[:tag] = tag
          response[:posts] = posts
          response[:projects] = projects
        end

        private

        def normalized_tag(request, response)
          tag = Blog::Types::Normalized::Tag.call(path_param(request, :tag)) { not_found(response) }
          own_path = routes.path(:tag, tag:)
          response.redirect_to(own_path, status: MOVED_PERMANENTLY) unless request.path == own_path
          tag
        end
      end
    end
  end
end
