# frozen_string_literal: true

module Public
  module UI
    module Views
      module Pages
        class Index < View
          include Components::Posts

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            h1(class: "sr-only") { t(".heading") }
            div(class: "g") do
              writing
              projects
            end
          end

          private

          def list_link(route, key)
            a(class: "sec-l", href: path(route)) do
              span { t(key) }
              Icon("fa-solid fa-arrow-right")
            end
          end

          def projects
            section do
              section_head(".projects", :projects, ".all_projects")
              @projects.empty? ? Empty { t(".no_projects") } : ProjectGrid(projects: @projects)
            end
          end

          def section_head(kicker, route, key)
            div(class: "sh") do
              h2(class: "kicker") { t(kicker) }
              list_link(route, key)
            end
          end

          def writing
            section do
              section_head(".writing", :writing, ".all_writing")
              @posts.empty? ? Empty { t(".no_writing") } : List(posts: @posts)
            end
          end
        end
      end
    end
  end
end
