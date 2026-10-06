# frozen_string_literal: true

module Public
  module UI
    module Views
      module Tags
        class Show < View
          include Components::Posts

          def initialize(tag:, posts:, projects:)
            super()
            @tag = tag
            @posts = posts
            @projects = projects
          end

          def view_template
            content_for(:title, t(".title", tag: @tag))
            content_for(:canonical, url(:tag, tag: @tag, **@posts.query))
            content_for(:feed, path(:tag_feed, tag: @tag)) unless @posts.rows.empty?

            section(class: "tagged") do
              h1(class: "page-title") { t(".heading", tag: @tag) }
              writing
              projects
            end
          end

          private

          def projects
            return if @projects.empty?

            h2(class: "tagged-title") { t(".projects") }
            ProjectGrid(projects: @projects)
          end

          def writing
            return if @posts.rows.empty?

            h2(class: "tagged-title") { t(".writing") }
            List(posts: @posts.rows)
            Pager(page: @posts, route: :tag, params: { tag: @tag })
          end
        end
      end
    end
  end
end
