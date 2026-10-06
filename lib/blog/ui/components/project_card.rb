# frozen_string_literal: true

module Blog
  module UI
    module Components
      class ProjectCard < Component
        STARS = :stars

        prop :name, Blog::Types::String
        prop :tagline, Blog::Types::String.optional
        prop :tags, Blog::Types::Array.of(Blog::Types::String), default: -> { [] }
        prop :stars, Blog::Types::Integer, default: 0
        prop :release, Blog::Types::String.optional
        prop :url, Blog::Types::String.optional

        def view_template
          card do
            span(class: "n") { @name }
            meta
            p { @tagline } if written?(@tagline)
          end
        end

        private

        def card(&)
          written?(@url) ? a(class: "proj", href: @url, &) : div(class: "proj", &)
        end

        def meta
          parts = meta_parts

          span(class: "s") { parts.each_with_index { |part, index| meta_part(part, index) } } unless parts.empty?
        end

        def meta_part(part, index)
          plain DOT if index.positive?
          part == STARS ? stars : plain(part)
        end

        def meta_parts
          parts = @tags.select { written?(it) }
          parts << STARS if @stars.positive?
          parts << @release if written?(@release)
          parts
        end

        def stars
          span(role: "img", aria: { label: t(".stars_label", count: @stars, stars: Figures.count(@stars)) }) do
            t(".stars", stars: Figures.count(@stars))
          end
        end
      end
    end
  end
end
