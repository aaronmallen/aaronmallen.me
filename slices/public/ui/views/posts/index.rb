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
            content_for(:feed, path(:writing_feed))

            section(class: "writing") do
              h1(class: "sr-only") { t(".heading") }
              span(class: "kicker") { t(".kicker") }
              @posts.empty? ? p(class: "writing-empty") { t(".empty") } : List(posts: @posts)
            end
          end
        end
      end
    end
  end
end
