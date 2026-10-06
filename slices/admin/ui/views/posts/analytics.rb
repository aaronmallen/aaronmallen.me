# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Analytics < View
          include Components::Analytics

          LABELS = {
            views: ".views", visitors: ".visitors", readers: ".readers", read_throughs: ".read_throughs",
          }.freeze
          RANGES = {
            "7" => "ui.views.posts.analytics.range_7",
            "14" => "ui.views.posts.analytics.range_14",
            "30" => "ui.views.posts.analytics.range_30",
          }.freeze
          SEPARATOR = " · "
          UNIQUE_NOTES = { true => ".final", false => ".first_year" }.freeze

          def initialize(
            post:, range:, views:, visitors:, bounces:, readers:, read_throughs:, scroll:, clicks:, countries:,
            devices:, referrers:, sources:, first_days:, unique_readers:
          )
            super()
            @post = post
            @range = range
            @stats = { views:, visitors:, bounces:, readers:, read_throughs: }
            @scroll = scroll
            @first_days = first_days
            @unique_readers = unique_readers
            @clicks = clicks
            @breakdowns = { countries:, devices:, referrers:, sources: }
          end

          def view_template
            PageHead(title: @post.title, kicker: t(".kicker"), sub:) do
              range_form
              Button(href: path(:admin_edit_post, id: @post.id)) { t(".edit") }
            end

            Grid(columns: 4) { stats }
            FirstDaysCard(**@first_days)

            Grid(columns: 2) do
              SideStack { left_cards }
              SideStack { right_cards }
            end
          end

          private

          def bounce_rate = Blog::Figures.share(stat(:bounces), stat(:visitors))

          def clicks = @clicks.map { { count: it[:clicks], label: it.values_at(:link_host, :link_path).join } }

          def countries = rows(:countries) { it[:country_code] || t(".unknown_country") }

          def devices = rows(:devices) { it[:device_class] }

          def figure(key, change: nil) = Stat(key: t(LABELS.fetch(key)), value: Blog::Figures.count(stat(key)), change:)

          def left_cards
            ScrollCard(reached: @scroll.fetch(:reached), views: @scroll.fetch(:views))
            MeterCard(color: :pink, empty: t(".no_devices"), rows: devices, title: t(".devices"))
            MeterCard(color: :blue, empty: t(".no_sources"), rows: sources, title: t(".sources"))
          end

          def month = l(Blog::TimeZone.today, format: :month)

          def range_form
            FilterSwitch(
              action: path(:admin_post_analytics, id: @post.id),
              name: "range",
              options: RANGES,
              selected: @range.to_s,
              label: t(".range"),
            )
          end

          def referrers = rows(:referrers) { it[:host] || t(".direct") }

          def right_cards
            MeterCard(color: :blue, empty: t(".no_referrers"), rows: referrers, title: t(".referrers"))
            MeterCard(color: :violet, empty: t(".no_countries"), rows: countries, title: t(".geography"))
            MeterCard(color: :pink, empty: t(".no_clicks"), rows: clicks, title: t(".clicks"))
          end

          def rows(name) = @breakdowns.fetch(name).map { { count: it[:visitors], label: yield(it) } }

          def sources = rows(:sources) { it[:source] }

          def stat(key) = @stats.fetch(key).to_i

          def stats
            figure(:views)
            figure(:visitors, change: t(".bounce", percent: bounce_rate))
            figure(:readers, change: t(".readers_note", month:))
            figure(:read_throughs, change: t(".read_note"))
            unique_readers
          end

          def sub = [t(".sub", count: @range), path(:post, slug: @post.slug)].join(SEPARATOR)

          def unique_readers
            readers, final = @unique_readers.values_at(:readers, :final)
            return Stat(key: t(".unique_readers"), value: t(".no_unique_readers"), change: t(".unkept")) unless readers

            Stat(key: t(".unique_readers"), value: Blog::Figures.count(readers), change: t(UNIQUE_NOTES.fetch(final)))
          end
        end
      end
    end
  end
end
