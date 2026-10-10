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

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :filter, Blog::Types::PostFilter
          prop :posts, Blog::Types::Instance(Blog::Structs::Paged)
          prop :read_through_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :saved_views, Blog::Types::Hash
          prop :suggestion_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :unique_reader_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Hash)
          prop :view_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :visitor_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :webmention_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :word_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)

          def view_template
            content_for(:title, t(".title"))
            PageHead(title: t(".heading"), sub:) do |head|
              head.tabs_side { SavedViews(**@saved_views) }
              filter_form
              CreateLink(href: path(:admin_new_post), label: t(".new_post"))
            end

            list
          end

          private

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

          def rows
            Card(class: "post-list", data: { key_list: true }) do
              Bulk(filter: @filter, page: @posts.number)
              @posts.rows.each { |post| Row(post:, filter: @filter, page: @posts.number, stats: stats(post)) }
            end
          end

          def stats(post)
            id = post.id

            {
              mentions: @webmention_counts.fetch(id, 0),
              read_throughs: @read_through_counts.fetch(id),
              suggestions: @suggestion_counts.fetch(id, 0),
              unique_readers: @unique_reader_counts.fetch(id),
              views: @view_counts.fetch(id),
              visitors: @visitor_counts.fetch(id),
              words: @word_counts.fetch(id),
            }
          end

          def sub
            drafts = t(".draft_count", count: count(DRAFT))

            t(".lede", drafts:, published: count(PUBLISHED), scheduled: count(SCHEDULED))
          end
        end
      end
    end
  end
end
