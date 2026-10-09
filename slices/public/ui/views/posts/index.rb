# frozen_string_literal: true

module Public
  module UI
    module Views
      module Posts
        class Index < View
          include Components::Posts

          prop :posts, Blog::Types::Instance(Blog::Structs::Paged)

          def view_template
            content_for(:title, t(".title"))
            content_for(:canonical, url(:writing, **@posts.query))

            section do
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
