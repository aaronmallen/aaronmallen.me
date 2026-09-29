# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Analytics
        class Show < View
          include Components::Analytics

          RANGES = { "7" => ".range_7", "14" => ".range_14", "30" => ".range_30" }.freeze
          SIGNED = "%+d"

          def initialize(
            change:, countries:, paths:, per_visit:, range:, read_time:, referrers:, series:, totals:, webmentions:
          )
            super()
            @countries = countries
            @paths = paths
            @range = range
            @referrers = referrers
            @series = series
            @stats = { change:, per_visit:, read_time:, **totals }
            @webmentions = webmentions
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @range)) { range_form }

            Grid(columns: 4) { stats }
            ChartCard(series: @series)

            Grid(columns: 2) do
              SideStack { PagesCard(paths: @paths) }
              SideStack { side_cards }
            end
          end

          private

          def change = @stats.fetch(:change)

          def change_text
            change ? t(".change", count: @range, percent: format(SIGNED, change)) : t(".no_prior")
          end

          def countries
            @countries.map { { count: it[:visitors], label: it[:country_code] || t(".unknown_country") } }
          end

          def mentioned_posts
            @webmentions.fetch(:posts).map { { count: it[:count], label: it[:title] } }
          end

          def per_visit = @stats.fetch(:per_visit)

          def range_form
            form(action: path(:admin_analytics), method: "get", data: { autosubmit: "" }) do
              SegmentedControl(label: t(".range"), name: "range", options: range_options, selected: @range.to_s)
              noscript { Button(type: "submit", small: true) { t(".apply") } }
            end
          end

          def range_options = RANGES.transform_values { t(it) }

          def read_time = @stats.fetch(:read_time)

          def referrers = @referrers.map { { count: it[:visitors], label: it[:host] || t(".direct") } }

          def side_cards
            MeterCard(color: :blue, empty: t(".no_referrers"), rows: referrers, title: t(".referrers"))
            MeterCard(color: :violet, empty: t(".no_countries"), rows: countries, title: t(".geography"))
            MeterCard(
              color: :pink, empty: t(".no_mentions"), rows: mentioned_posts, title: t(".mentioned_posts"),
            )
          end

          def stats
            views_stat
            Stat(key: t(".visitors"), value: Blog::Figures.count(visitors), change: t(".per_visit", rate: per_visit))
            Stat(key: t(".read"), value: Blog::Figures.duration(read_time), change: t(".read_note"))
            webmentions_stat
          end

          def views = @stats.fetch(:views)

          def views_stat
            Stat(
              key: t(".views"),
              value: Blog::Figures.count(views),
              change: change_text,
              down: change.to_i.negative?,
            )
          end

          def visitors = @stats.fetch(:visitors)

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
