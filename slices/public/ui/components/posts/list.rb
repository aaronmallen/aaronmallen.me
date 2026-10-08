# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class List < Component
          TEASER_LIMIT = 120

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            ol(class: "entries h-feed") do
              @posts.each { |post| entry(post) }
            end
          end

          private

          def entry(post)
            li(class: "entry h-entry") do
              div(class: "entry-meta") do
                Date(time: post.published_at)
                Tags(tags: post.tags)
                span { t(".read_time", count: post.read_time) }
              end
              div { entry_heading(post) }
            end
          end

          def entry_heading(post)
            h2(class: "entry-title") do
              a(class: "entry-link p-name u-url", href: path(:post, slug: post.slug)) do
                post.title
              end
            end
            blurb = teaser(post)
            p(class: "entry-blurb p-summary") { blurb } if blurb
          end

          def teaser(post)
            paragraph = post.summary
            return unless paragraph

            Blog::Helpers::Truncation.cut(paragraph, keep: TEASER_LIMIT)
          end
        end
      end
    end
  end
end
