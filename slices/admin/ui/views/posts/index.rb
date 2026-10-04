# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Index < View
          include Components::Posts

          ALL = Blog::Types::PostFilter["all"]
          DRAFT = Blog::Types::PostStatus["draft"]
          PUBLISHED = Blog::Types::PostStatus["published"]
          SCHEDULED = Blog::Types::PostStatus["scheduled"]

          FILTERS = { ALL => ".all", PUBLISHED => ".published", DRAFT => ".drafts",
                      SCHEDULED => ".scheduled" }.freeze
          MENTION_COLOR = :pink
          SEPARATOR = " · "

          def initialize(
            counts:, filter:, posts:, read_through_counts:, view_counts:, visitor_counts:, webmention_counts:,
            word_counts:
          )
            super()
            @counts = counts
            @filter = filter
            @posts = posts
            @read_through_counts = read_through_counts
            @view_counts = view_counts
            @visitor_counts = visitor_counts
            @webmention_counts = webmention_counts
            @word_counts = word_counts
          end

          def view_template
            PageHead(title: t(".heading"), sub:) do
              filter_form
              a(class: "btn pri", href: path(:admin_new_post)) do
                i(class: "fa-solid fa-plus", aria: { hidden: "true" })
                span { t(".new_post") }
              end
            end

            list
          end

          private

          def analytics_link(post)
            label = t(".analytics", title: post.title)

            a(class: "btn sm", href: path(:admin_post_analytics, id: post.id), title: label, aria: { label: }) do
              i(class: "fa-solid fa-chart-simple", aria: { hidden: "true" })
            end
          end

          def count(status) = @counts.fetch(status, 0)

          def filter_form
            form(action: path(:admin_posts), method: "get", data: { autosubmit: "" }) do
              SegmentedControl(label: t(".filter"), name: "status", options: filter_options, selected: @filter)
              noscript { Button(type: "submit", small: true) { t(".apply") } }
            end
          end

          def filter_options = FILTERS.transform_values { t(it) }

          def list
            @posts.rows.empty? ? Empty { t(".empty") } : rows
            Pager(page: @posts, route: :admin_posts, params: { status: @filter })
          end

          def mentions(post)
            count = @webmention_counts.fetch(post.id, 0)
            return unless count.positive?

            Pill(color: MENTION_COLOR) do
              span(aria: { hidden: "true" }) { t(".mentions", count:) }
              span(class: "sr-only") { t(".mentions_label", count:) }
            end
          end

          def readership(post)
            [
              t(".views", count: @view_counts.fetch(post.id)),
              t(".visitors", count: @visitor_counts.fetch(post.id)),
              t(".read_throughs", count: @read_through_counts.fetch(post.id)),
            ]
          end

          def row(post)
            ListItem(title: post.title, href: path(:admin_edit_post, id: post.id), sub: row_sub(post)) do
              analytics_link(post)
              Tags(tags: post.tags)
              mentions(post)
              StatusPill(status: post.status)
            end
          end

          def row_sub(post)
            date = l(Blog::TimeZone.today(post.published_at || post.updated_at), format: :medium)
            words = t(".words", count: @word_counts.fetch(post.id))
            [path(:post, slug: post.slug), date, words, *readership(post)].join(SEPARATOR)
          end

          def rows = Card(data: { key_list: true }) { @posts.rows.each { |post| row(post) } }

          def sub
            [
              t(".published_count", count: count(PUBLISHED)),
              t(".draft_count", count: count(DRAFT)),
              t(".scheduled_count", count: count(SCHEDULED)),
            ].join(SEPARATOR)
          end
        end
      end
    end
  end
end
