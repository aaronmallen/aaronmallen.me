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
            section(class: "home") do
              h1(class: "sr-only") { t(".heading") }
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
            section(class: "sec") do
              section_head(".projects", :projects, ".all_projects")
              @projects.empty? ? Empty { t(".no_projects") } : ProjectGrid(projects: @projects)
            end
          end

          def section_head(kicker, route, key)
            div(class: "sec-h") do
              span(class: "kicker") { t(kicker) }
              list_link(route, key)
            end
          end

          def writing
            section(class: "sec") do
              section_head(".writing", :writing, ".all_writing")
              @posts.empty? ? Empty { t(".no_writing") } : List(posts: @posts)
            end
          end
        end
      end
    end
  end
end
