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

          FILTERS = {
            ALL => "ui.views.posts.index.all",
            PUBLISHED => "ui.views.posts.index.published",
            DRAFT => "ui.views.posts.index.drafts",
            SCHEDULED => "ui.views.posts.index.scheduled",
          }.freeze
          MENTION_COLOR = :pink
          SEPARATOR = " · "
          UNIQUE_READERS = { true => ".final_unique_readers", false => ".unique_readers" }.freeze

          def initialize(
            counts:, filter:, posts:, read_through_counts:, saved_views:, unique_reader_counts:, view_counts:,
            visitor_counts:, webmention_counts:, word_counts:
          )
            super()
            @counts = counts
            @filter = filter
            @posts = posts
            @saved_views = saved_views
            @readership = { read_throughs: read_through_counts, views: view_counts, visitors: visitor_counts }
            @unique_reader_counts = unique_reader_counts
            @webmention_counts = webmention_counts
            @word_counts = word_counts
          end

          def view_template
            PageHead(title: t(".heading"), sub:) do
              SavedViews(**@saved_views)
              filter_form
              CreateLink(href: path(:admin_new_post), label: t(".new_post"))
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
            FilterSwitch(
              action: path(:admin_posts),
              name: "status",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

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

          def pick(post) = { form: Bulk::ID, value: post.id, label: t(".pick", title: post.title) }

          def readership(post)
            [
              t(".views", count: tally(:views, post)),
              t(".visitors", count: tally(:visitors, post)),
              unique_readers(post),
              t(".read_throughs", count: tally(:read_throughs, post)),
            ]
          end

          def row(post)
            href = path(:admin_edit_post, id: post.id)

            ListItem(title: post.title, href:, sub: row_sub(post), pick: pick(post)) do
              PublishForm(post:, filter: @filter, page: @posts.number) if post.status == DRAFT
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

          def rows
            Card(data: { key_list: true }) do
              Bulk(filter: @filter, page: @posts.number)
              @posts.rows.each { |post| row(post) }
            end
          end

          def sub
            [
              t(".published_count", count: count(PUBLISHED)),
              t(".draft_count", count: count(DRAFT)),
              t(".scheduled_count", count: count(SCHEDULED)),
            ].join(SEPARATOR)
          end

          def tally(name, post) = @readership.fetch(name).fetch(post.id)

          def unique_readers(post)
            readers, final = @unique_reader_counts.fetch(post.id).values_at(:readers, :final)
            return t(".no_unique_readers") unless readers

            t(UNIQUE_READERS.fetch(final), count: readers)
          end
        end
      end
    end
  end
end
