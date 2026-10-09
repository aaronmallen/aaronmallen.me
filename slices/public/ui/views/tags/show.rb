# frozen_string_literal: true

module Public
  module UI
    module Views
      module Tags
        class Show < View
          include Components::Posts

          prop :tag, Blog::Types::String
          prop :posts, Blog::Types::Instance(Blog::Structs::Paged)
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            content_for(:title, t(".title", tag: @tag))
            content_for(:canonical, url(:tag, tag: @tag, **@posts.query))
            content_for(:feed, path(:tag_feed, tag: @tag)) unless @posts.rows.empty?

            section do
              header(class: "hd") { h1 { t(".heading", tag: @tag) } }
              writing
              projects
            end
          end

          private

          def projects
            return if @projects.empty?

            h2(class: "kicker kt") { t(".projects") }
            ProjectGrid(projects: @projects)
          end

          def writing
            return if @posts.rows.empty?

            h2(class: "kicker") { t(".writing") }
            List(posts: @posts.rows)
            Pager(page: @posts, route: :tag, params: { tag: @tag })
          end
        end
      end
    end
  end
end
