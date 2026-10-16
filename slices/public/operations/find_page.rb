# frozen_string_literal: true

module Public
  module Operations
    class FindPage
      FEED = ".atom"
      PAGES = %i[root writing about projects contact].freeze

      include Deps[
        post_queries: "posts.repos.post_queries",
        project_queries: "projects.repos.project_queries",
        routes: "routes",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(route)
        params = route.params
        return false if route.path.end_with?(FEED)
        return board_page?(params) if on_board?(route.path)
        return post?(unescape(params[:slug])) if params.key?(:slug)
        return tag?(unescape(params[:tag])) if params.key?(:tag)

        PAGES.any? { routes.path(it) == route.path }
      end

      private

      def board(slug) = (project_queries.public_board(slug) if Blog::Types::Slug.valid?(slug))

      def board_page?(params)
        project = board(unescape(params[:slug]))
        return !project.nil? unless project && params.key?(:number)

        task?(project, Blog::Types::Id.call(params[:number]) { nil })
      end

      def on_board?(path) = path.start_with?("#{routes.path(:projects)}/")

      def post?(slug) = Blog::Types::Slug.valid?(slug) && post_queries.published_slug?(slug)

      def tag?(tag)
        return false unless tag == Blog::Types::Normalized::Tag.call(tag) { nil }

        post_queries.published_tag?(tag) || project_queries.public_tag?(tag)
      end

      def task?(project, number) = !number.nil? && !task_queries.on_public_board_by_number(project.id, number).nil?

      def unescape(value) = ::Rack::Utils.unescape_path(value.to_s)
    end
  end
end
