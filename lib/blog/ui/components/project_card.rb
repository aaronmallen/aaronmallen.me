# frozen_string_literal: true

module Blog
  module UI
    module Components
      class ProjectCard < Component
        SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i
        STARS = :stars

        prop :name, Blog::Types::String
        prop :tagline, Blog::Types::String.optional
        prop :tags, Blog::Types::Array.of(Blog::Types::String), default: -> { [] }
        prop :stars, Blog::Types::Integer, default: 0
        prop :release, Blog::Types::String.optional
        prop :url, Blog::Types::String.optional
        prop :past, Blog::Types::Bool, default: false

        def view_template
          card do
            span(class: "pn") { @name }
            meta
            p { @tagline } if written?(@tagline)
            foot
          end
        end

        private

        def card(&)
          classes = ["pc", ("past" if @past)]
          written?(@url) ? a(class: classes, href: @url, &) : div(class: classes, &)
        end

        def foot
          return unless written?(@url)

          span(class: "pu") do
            plain @url.sub(SCHEME, "")
            Icon("fa-solid fa-arrow-up-right-from-square")
          end
        end

        def meta
          parts = meta_parts

          span(class: "ps") { parts.each_with_index { |part, index| meta_part(part, index) } } unless parts.empty?
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
          span(role: "img", aria: { label: t(".stars_label", count: @stars, stars: Helpers::Figures.count(@stars)) }) do
            t(".stars", stars: Helpers::Figures.count(@stars))
          end
        end
      end
    end
  end
end
