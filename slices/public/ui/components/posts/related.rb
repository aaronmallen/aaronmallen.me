# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Related < Component
          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            return if @posts.empty?

            section(class: "rel", aria: { labelledby: "rel-h" }) do
              h2(class: "kicker", id: "rel-h") { t(".heading") }
              ol do
                @posts.each { |post| card(post) }
              end
            end
          end

          private

          def card(post)
            li do
              a(class: "rt", href: path(:post, slug: post.slug)) { post.title }
              p(class: "rs") { post.summary } if post.summary
              p(class: "rm") do
                Date(time: post.published_at)
                reason(post)
              end
            end
          end

          def hue(tag) = Blog::UI::Components::Pill.for_tag_color(tag.color).to_s

          def reason(post)
            shared = post.tags.select { |tag| @tags.any? { it.id == tag.id } }
            return span { t(".wording") } if shared.empty?

            span do
              plain t(".shares")
              shared.each do |tag|
                whitespace
                a(class: ["post-tag", hue(tag)], href: path(:tag, tag: tag.name)) { tag.name }
              end
            end
          end
        end
      end
    end
  end
end
