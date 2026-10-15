# frozen_string_literal: true

module Public
  module UI
    module Components
      class SearchWays < Component
        prop :tags, Blog::Types::Array.of(Blog::Types::Hash)
        prop :latest, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

        def view_template
          div(class: "sq-w") do
            tags
            latest
          end
        end

        private

        def chip(tag)
          li do
            a(class: Blog::UI::Components::Pill.for_tag_color(tag[:color]).to_s, href: path(:tag, tag: tag[:name])) do
              plain tag[:name]
              whitespace
              span { tag[:count].to_s }
            end
          end
        end

        def latest
          return if @latest.empty?

          section(aria: { labelledby: "w-rec" }) do
            latest_head
            ol(class: "rcl") { @latest.each { recent(it) } }
          end
        end

        def latest_head
          div(class: "sh") do
            h2(class: "kicker", id: "w-rec") { t(".latest") }
            a(class: "sec-l", href: path(:writing)) do
              span { t(".writing") }
              Icon("fa-solid fa-arrow-right")
            end
          end
        end

        def recent(post)
          day = Blog::TimeZone.local(post.published_at).to_date

          li do
            a(href: path(:post, slug: post.slug)) { post.title }
            time(datetime: day.iso8601) { l(day, format: :short) }
          end
        end

        def tags
          return if @tags.empty?

          section(aria: { labelledby: "w-tags" }) do
            h2(class: "kicker", id: "w-tags") { t(".tags") }
            ul(class: "tgc") { @tags.each { chip(it) } }
          end
        end
      end
    end
  end
end
