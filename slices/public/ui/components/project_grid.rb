# frozen_string_literal: true

module Public
  module UI
    module Components
      class ProjectGrid < Component
        prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :past, Blog::Types::Bool, default: false

        def view_template
          div(class: "pgrid") do
            @projects.each { |project| card(project) }
          end
        end

        private

        def card(project)
          ProjectCard(
            name: project.name,
            tagline: project.tagline,
            tags: project.tags.map(&:name),
            stars: project.stars,
            release: project.release,
            url: project.url,
            past: @past,
          )
        end
      end
    end
  end
end
