# frozen_string_literal: true

module Public
  module UI
    module Views
      module Posts
        class Index < View
          include Components::Posts

          def initialize(posts:)
            super()
            @posts = posts
          end

          def view_template
            content_for(:title, t(".title"))
            content_for(:canonical, Blog::Site.url(path(:writing, **@posts.query)))

            section(class: "writing") do
              h1(class: "sr-only") { t(".heading") }
              span(class: "kicker") { t(".kicker") }
              @posts.rows.empty? ? p(class: "writing-empty") { t(".empty") } : entries
            end
          end

          private

          def entries
            List(posts: @posts.rows)
            Pager(page: @posts, route: :writing)
          end
        end
      end
    end
  end
end
