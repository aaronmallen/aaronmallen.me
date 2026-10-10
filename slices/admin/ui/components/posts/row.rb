# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Row < Component
          DRAFT = Blog::Types::PostStatus["draft"]
          MENTION_COLOR = :pink
          UNIQUE_READERS = { true => ".final_unique_readers", false => ".unique_readers" }.freeze

          prop :post, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :page, Blog::Types::Integer
          prop :stats, Blog::Types::Hash

          def view_template
            ListItem(title: @post.title, href: path(:admin_edit_post, id: @post.id), sub:, pick:) do |item|
              item.meta { meta }
              PublishForm(post: @post, filter: @filter, page: @page) if @post.status == DRAFT
              analytics_link
              StatusPill(status: @post.status)
            end
          end

          private

          def analytics_link
            label = t(".analytics", title: @post.title)

            Button(
              href: path(:admin_post_analytics, id: @post.id), label:, small: true,
              icon: "fa-solid fa-chart-simple",
            )
          end

          def mentions
            count = @stats.fetch(:mentions)
            return unless count.positive?

            Pill(color: MENTION_COLOR) do
              span(aria: { hidden: "true" }) { t(".mentions", count:) }
              span(class: "sr-only") { t(".mentions_label", count:) }
            end
          end

          def meta
            div(class: "post-row-meta") do
              mentions
              suggestions
              @post.tags.each { Tag(tag: it) }
            end
          end

          def pick = { form: Bulk::ID, value: @post.id, label: t(".pick", title: @post.title) }

          def readership
            [
              t(".views", count: @stats.fetch(:views)),
              t(".visitors", count: @stats.fetch(:visitors)),
              unique_readers,
              t(".read_throughs", count: @stats.fetch(:read_throughs)),
            ]
          end

          def sub
            date = l(Blog::TimeZone.today(@post.published_at || @post.updated_at), format: :medium)
            words = t(".words", count: @stats.fetch(:words))
            dotted(path(:post, slug: @post.slug), date, words, *readership)
          end

          def suggestions
            count = @stats.fetch(:suggestions)
            return unless count.positive?

            Pill(color: :blue) { IconLabel(icon: "fa-solid fa-robot") { t(".suggestions", count:) } }
          end

          def unique_readers
            readers, final = @stats.fetch(:unique_readers).values_at(:readers, :final)
            return t(".no_unique_readers") unless readers

            t(UNIQUE_READERS.fetch(final), count: readers)
          end
        end
      end
    end
  end
end
