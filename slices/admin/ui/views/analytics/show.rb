# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Analytics
        class Show < View
          include Components::Analytics

          SIGNED = "%+d"

          prop :change, Blog::Types::Integer.optional, reader: :private
          prop :countries, Blog::Types::Array.of(Blog::Types::Hash)
          prop :feed, Blog::Types::Hash
          prop :paths, Blog::Types::Array.of(Blog::Types::Hash)
          prop :per_visit, Blog::Types::Float, reader: :private
          prop :range, Blog::Types::AnalyticsRange
          prop :read_time, Blog::Types::Integer, reader: :private
          prop :referrers, Blog::Types::Array.of(Blog::Types::Hash)
          prop :series, Blog::Types::Array.of(Blog::Types::Hash)
          prop :totals, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :webmentions, Blog::Types::Hash
          prop :weekday_hours, Blog::Types::Hash

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @range)) { range_form }

            Grid(columns: 4) { stats }
            ChartCard(series: @series)

            Grid(columns: 2) do
              SideStack do
                PagesCard(paths: @paths)
                HourGridCard(**@weekday_hours)
              end
              SideStack { side_cards }
            end
          end

          private

          def aggregators
            @feed.fetch(:aggregators).map { { count: it[:subscribers], label: it[:aggregator] } }
          end

          def change_text
            change ? t(".change", count: @range, percent: format(SIGNED, change)) : t(".no_prior")
          end

          def feed_cards
            FeedCard(**@feed.slice(:days, :latest))
            MeterCard(color: :blue, empty: t(".no_aggregators"), rows: aggregators, title: t(".aggregators"))
          end

          def mentioned_posts
            @webmentions.fetch(:posts).map { { count: it[:count], label: it[:title] } }
          end

          def range_form
            FilterSwitch(
              action: path(:admin_analytics),
              name: "range",
              options: RANGES,
              selected: @range.to_s,
              label: t(".range"),
            )
          end

          def side_cards
            ReferrersCard(rows: @referrers)
            CountriesCard(rows: @countries)
            MeterCard(
              color: :pink, empty: t(".no_mentions"), rows: mentioned_posts, title: t(".mentioned_posts"),
            )
            feed_cards
          end

          def stats
            views_stat
            Stat(key: t(".visitors"), value: Blog::Figures.count(visitors), change: t(".per_visit", rate: per_visit))
            Stat(key: t(".read"), value: Blog::Figures.duration(read_time), change: t(".read_note"))
            webmentions_stat
          end

          def views = @totals.fetch(:views)

          def views_stat
            Stat(
              key: t(".views"),
              value: Blog::Figures.count(views),
              change: change_text,
              down: change.to_i.negative?,
            )
          end

          def visitors = @totals.fetch(:visitors)

          def webmentions_stat
            Stat(
              key: t(".webmentions"),
              value: Blog::Figures.count(@webmentions.fetch(:received)),
              change: t(".pending", count: @webmentions.fetch(:pending)),
            )
          end
        end
      end
    end
  end
end
