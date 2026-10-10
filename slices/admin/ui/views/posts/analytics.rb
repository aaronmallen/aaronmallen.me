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
          UNIQUE_NOTES = { true => ".final", false => ".first_year" }.freeze

          prop :post, Blog::Types::Instance(ROM::Struct)
          prop :range, Blog::Types::AnalyticsRange
          prop :views, Blog::Types::Integer
          prop :visitors, Blog::Types::Integer
          prop :bounces, Blog::Types::Integer
          prop :readers, Blog::Types::Integer
          prop :read_throughs, Blog::Types::Integer
          prop :scroll, Blog::Types::Hash
          prop :clicks, Blog::Types::Array.of(Blog::Types::Hash)
          prop :countries, Blog::Types::Array.of(Blog::Types::Hash)
          prop :devices, Blog::Types::Array.of(Blog::Types::Hash)
          prop :referrers, Blog::Types::Array.of(Blog::Types::Hash)
          prop :sources, Blog::Types::Array.of(Blog::Types::Hash)
          prop :first_days, Blog::Types::Hash
          prop :unique_readers, Blog::Types::Hash

          def view_template
            PageHead(title: @post.title, kicker: t(".kicker"), sub:) { actions }

            div(class: "post-analytics") do
              Grid(columns: 4) { stats }
              FirstDaysCard(**@first_days)
              div(class: "cols") { cards }
            end
          end

          private

          def actions
            BackLink(href: path(:admin_posts)) { t(".back") }
            range_form
            Button(href: path(:admin_edit_post, id: @post.id), icon: "fa-regular fa-pen-to-square") { t(".edit") }
          end

          def bounce_rate = Blog::Helpers::Figures.share(stat(:bounces), stat(:visitors))

          def cards
            MeterCard(color: :blue, empty: t(".no_sources"), rows: sources, title: t(".sources"))
            MeterCard(color: :pink, empty: t(".no_devices"), rows: devices, title: t(".devices"))
            ScrollCard(reached: @scroll.fetch(:reached), views: @scroll.fetch(:views))
            MeterCard(color: :pink, empty: t(".no_clicks"), rows: clicks, title: t(".clicks"))
            ReferrersCard(rows: @referrers)
            CountriesCard(rows: @countries)
          end

          def clicks = @clicks.map { { count: it[:clicks], label: it.values_at(:link_host, :link_path).join } }

          def devices = rows(@devices) { it[:device_class] }

          def figure(key, change: nil)
            Stat(key: t(LABELS.fetch(key)), value: Blog::Helpers::Figures.count(stat(key)), change:)
          end

          def figures
            { views: @views, visitors: @visitors, bounces: @bounces, readers: @readers, read_throughs: @read_throughs }
          end

          def month = l(Blog::TimeZone.today, format: :month)

          def range_form = RangeSwitch(action: path(:admin_post_analytics, id: @post.id), range: @range)

          def rows(list) = list.map { { count: it[:visitors], label: yield(it) } }

          def sources = rows(@sources) { it[:source] }

          def stat(key) = figures.fetch(key).to_i

          def stats
            figure(:views)
            figure(:visitors, change: t(".bounce", percent: bounce_rate))
            figure(:readers, change: t(".readers_note", month:))
            figure(:read_throughs, change: t(".read_note"))
            unique_readers
          end

          def sub
            t(
              ".lede",
              readers: t(".reader_count", count: stat(:readers)),
              read_throughs: t(".read_through_count", count: stat(:read_throughs)),
              count: @range,
              path: path(:post, slug: @post.slug),
            )
          end

          def unique_readers
            readers, final = @unique_readers.values_at(:readers, :final)
            return Stat(key: t(".unique_readers"), value: t(".no_unique_readers"), change: t(".unkept")) unless readers

            change = t(UNIQUE_NOTES.fetch(final))

            Stat(key: t(".unique_readers"), value: Blog::Helpers::Figures.count(readers), change:)
          end
        end
      end
    end
  end
end
