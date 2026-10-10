# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Analytics
        class Show < View
          include Components::Analytics

          prop :change, Blog::Types::Integer.optional, reader: :private
          prop :countries, Blog::Types::Array.of(Blog::Types::Hash)
          prop :feed, Blog::Types::Hash
          prop :paths, Blog::Types::Array.of(Blog::Types::Hash)
          prop :per_visit, Blog::Types::Float, reader: :private
          prop :range, Blog::Types::AnalyticsRange
          prop :read_time, Blog::Types::Integer, reader: :private
          prop :referrers, Blog::Types::Array.of(Blog::Types::Hash)
          prop :scroll, Blog::Types::Hash
          prop :series, Blog::Types::Array.of(Blog::Types::Hash)
          prop :totals, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :webmentions, Blog::Types::Hash
          prop :weekday_hours, Blog::Types::Hash

          def view_template
            PageHead(title: t(".heading"), sub:) { range_form }

            div(class: "insights") do
              ChartCard(series: @series)
              div(class: "cols") { cards }
            end
          end

          private

          def cards
            PagesCard(paths: @paths)
            HourGridCard(**@weekday_hours)
            ReferrersCard(rows: @referrers)
            CountriesCard(rows: @countries)
            ScrollCard(reached: @scroll.fetch(:reached), views: @scroll.fetch(:views))
            FeedCard(**@feed.slice(:aggregators, :days, :latest))
            mentions_card
          end

          def change_text
            return t(".no_prior") unless change

            t(change.negative? ? ".down" : ".up", count: @range, percent: change.abs)
          end

          def count(number) = Blog::Helpers::Figures.count(number)

          def mentioned_posts
            @webmentions.fetch(:posts).map { { count: it[:count], label: it[:title] } }
          end

          def mentions_card
            received, pending = @webmentions.values_at(:received, :pending)

            MeterCard(
              color: :pink, empty: t(".no_mentions"), rows: mentioned_posts, title: t(".mentioned_posts"),
              side: dotted(t(".received", count: received, formatted: count(received)), t(".pending", count: pending)),
            )
          end

          def range_form = RangeSwitch(action: path(:admin_analytics), range: @range)

          def sub
            t(
              ".lede",
              views: t(".views", count: views, formatted: count(views)),
              visitors: t(".visitors", count: visitors, formatted: count(visitors)),
              count: @range,
              change: change_text,
              per_visit:,
              read: Blog::Helpers::Figures.duration(read_time),
            )
          end

          def views = @totals.fetch(:views)

          def visitors = @totals.fetch(:visitors)
        end
      end
    end
  end
end
