# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Preview < Component
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :release, Blog::Types::String.optional
          prop :stars, Blog::Types::Integer

          def view_template
            Card(label: t(".heading"), title: t(".title")) do
              div(class: "projs", data: preview_data) { card }
            end
          end

          private

          def card
            render Blog::UI::Components::ProjectCard.new(
              name: name,
              tagline: tagline,
              tags: Blog::Types::TagList[@values[:tags]],
              stars: @stars,
              release: @release,
              url: written(@values[:url]),
            )
          end

          def name = written(@values[:name]) || t(".name_placeholder")

          def preview_data
            { editor_preview: "", name: t(".name_placeholder"), tagline: t(".tagline_placeholder") }
          end

          def tagline = written(@values[:tagline]) || t(".tagline_placeholder")

          def written(value)
            stripped = value.strip

            stripped unless stripped.empty?
          end
        end
      end
    end
  end
end
