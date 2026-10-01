# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeAnalytics
      KEYS = { countries: :country_code, paths: :path, referrers: :host }.freeze
      RANKS = { countries: :visitors, paths: :views, referrers: :visitors }.freeze
      SUMS = {
        countries: %i[views visitors].freeze,
        paths: %i[views visitors read_seconds bounces].freeze,
        referrers: %i[views visitors].freeze,
      }.freeze
      TOP_ROWS = 10
      TOTALS = %i[views visitors read_seconds].freeze
      ZERO_DAY = { views: 0, visitors: 0 }.freeze

      include Deps[
        country_counts: "analytics.queries.country_counts",
        pending_webmention_count: "social.queries.pending_webmention_count",
        posts_by_ids: "posts.queries.by_ids",
        referrer_counts: "analytics.queries.referrer_counts",
        rollups_between: "analytics.queries.rollups_between",
        top_paths: "analytics.queries.top_paths",
        unrolled_summaries: "analytics.queries.unrolled_summaries",
        view_totals: "analytics.queries.view_totals",
        webmentions_received_between: "social.queries.webmentions_received_between",
        webmentions_received_by_post: "social.queries.webmentions_received_by_post",
      ]

      def call(range:)
        to = Blog::TimeZone.today
        from = to - (range - 1)
        before = view_totals.call(from: from - range, to: from - 1).to_h
        found = period(from, to)

        { range:, webmentions: webmentions(from, to), **found, **stats(found.fetch(:totals), before) }
      end

      private

      def combine(rows, key, fields)
        rows.each_with_object({}) do |row, found|
          held = found[row[key]]
          found[row[key]] = held ? held.merge(row, totals_of(held, row, fields)) : row
        end.values
      end

      def mentioned_posts(counts)
        rows = posts_by_ids.call(counts.keys).map { { count: counts.fetch(it.id), title: it.title } }

        rows.sort_by { [-it[:count], it[:title]] }.take(TOP_ROWS)
      end

      def period(from, to)
        live = unrolled_summaries.call(from:, to:)

        {
          countries: ranked(:countries, country_counts.call(from:, to:), live).take(TOP_ROWS),
          paths: ranked(:paths, top_paths.call(from:, to:), live).take(TOP_ROWS),
          referrers: ranked(:referrers, referrer_counts.call(from:, to:), live).take(TOP_ROWS),
          series: series(from, to, live),
          totals: totals(from, to, live),
        }
      end

      def ranked(name, rolled, live)
        key = KEYS.fetch(name)
        rank = RANKS.fetch(name)
        so_far = live.flat_map { it.public_send(name) }

        combine((rolled + so_far).map(&:to_h), key, SUMS.fetch(name)).sort_by { standing(it, rank, key) }
      end

      def series(from, to, live)
        found = rollups_between.call(from:, to:).to_h { [it.day, { views: it.views, visitors: it.visitors }] }
        live.each { found[it.day] = it.totals.to_h.slice(*ZERO_DAY.keys) }

        (from..to).map { { day: it, **found.fetch(it, ZERO_DAY) } }
      end

      def standing(row, rank, key) = [row[rank] ? 0 : 1, -row[rank].to_i, -row[:views], row[key].to_s]

      def stats(totals, before)
        views = totals.fetch(:views)
        prior = before.fetch(:views)

        {
          change: (Blog::Figures.share(views - prior, prior) if prior.positive?),
          per_visit: Blog::Figures.rate(views, totals.fetch(:visitors)),
          read_time: Blog::Figures.average(totals.fetch(:read_seconds), views),
        }
      end

      def sum(held, found) = held && found ? held + found : held || found

      def totals(from, to, live)
        found = view_totals.call(from:, to:).to_h

        TOTALS.to_h { |key| [key, live.sum(found.fetch(key)) { it.totals.public_send(key) }] }
      end

      def totals_of(held, row, fields) = fields.to_h { [it, sum(held[it], row[it])] }

      def webmentions(from, to)
        {
          pending: pending_webmention_count.call,
          posts: mentioned_posts(webmentions_received_by_post.call(from:, to:)),
          received: webmentions_received_between.call(from:, to:),
        }
      end
    end
  end
end
