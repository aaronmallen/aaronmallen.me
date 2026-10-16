# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Index < View
          include Components::Posts

          ALL = Blog::Types::PostFilter["all"]
          BROKEN = Blog::Types::PostFilter["broken"]
          DRAFT = Blog::Types::PostStatus["draft"]
          LIVE_TABLES = %w[
            analytics_rollup_paths link_check_runs post_link_checks post_tags posts saved_views short_link_checks
            suggestions
          ].freeze
          PUBLISHED = Blog::Types::PostStatus["published"]
          SCHEDULED = Blog::Types::PostStatus["scheduled"]

          FILTERS = {
            ALL => "ui.views.posts.index.all",
            PUBLISHED => "ui.views.posts.index.published",
            DRAFT => "ui.views.posts.index.drafts",
            SCHEDULED => "ui.views.posts.index.scheduled",
          }.freeze

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :failing_links, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Array)
          prop :figures, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Hash)
          prop :link_check, Blog::Types::Hash
          prop :filter, Blog::Types::PostFilter
          prop :posts, Blog::Types::Instance(Blog::Structs::Paged)
          prop :saved_views, Blog::Types::Hash
          prop :suggestion_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            content_for(:title, t(".title"))
            PageHead(title: t(".heading"), sub:) do |head|
              head.tabs_side { SavedViews(**@saved_views) }
              filter_form
              CreateLink(href: path(:admin_new_post), label: t(".new_post"))
            end

            list
          end

          private

          def broken? = @filter == BROKEN

          def broken_count = @link_check[:links] + @link_check[:short_links].size

          def broken_sub
            return t(".nothing_broken") if broken_count.zero?

            [
              t(
                ".broken_lede",
                count: broken_count, in_posts: @link_check[:links],
                posts: t(".post_count", count: @link_check[:posts]),
                short_links: t(".short_link_count", count: @link_check[:short_links].size),
              ),
              finished,
            ].compact.join(" ")
          end

          def check_form
            Form(id: FailingLinks::FORM, action: path(:admin_posts), data: { morph: true }) do
              input(type: "hidden", name: "return_to", value: path(:admin_posts, **list_query))
            end
          end

          def count(status) = @counts.fetch(status, 0)

          def empty = broken? ? ".no_broken_posts" : ".empty"

          def filter_form
            AutoForm(action: path(:admin_posts)) do
              SegmentedControl(label: t(".filter"), name: "status", options: filters, selected: @filter)
            end
          end

          def filters
            labels = FILTERS.transform_values { t(it) }
            labels.merge(BROKEN => broken_count.zero? ? t(".broken") : t(".broken_count", count: broken_count))
          end

          def finished
            at = @link_check[:run]&.finished_at
            t(".finished", at: l(Blog::TimeZone.local(at), format: :short)) if at
          end

          def list
            LinkCheckBanner(run: @link_check[:run], return_to: path(:admin_posts, **list_query)) if broken?
            check_form if broken?
            @posts.rows.empty? ? Empty { t(empty) } : rows
            Pager(page: @posts, route: :admin_posts, params: { status: @filter })
            short_links if broken?
          end

          def list_query = { status: @filter, **Blog::Structs::Page.query(@posts.number) }

          def rows
            Card(class: "post-list", data: { key_list: true }) do
              Bulk(filter: @filter, page: @posts.number)
              @posts.rows.each do |post|
                failing = @failing_links.fetch(post.id, Blog::Constants::EMPTY_ARRAY)
                Row(post:, filter: @filter, page: @posts.number, stats: stats(post), failing:)
                FailingLinks(post_id: post.id, links: failing) if broken? && failing.any?
              end
            end
          end

          def short_links
            links = @link_check[:short_links]
            BrokenShortLinks(links:, total: @link_check[:short_total]) if links.any?
          end

          def stats(post)
            { **@figures.fetch(post.id), suggestions: @suggestion_counts.fetch(post.id, 0), words: post.word_count }
          end

          def sub
            return broken_sub if broken?

            drafts = t(".draft_count", count: count(DRAFT))

            t(".lede", drafts:, published: count(PUBLISHED), scheduled: count(SCHEDULED))
          end
        end
      end
    end
  end
end
