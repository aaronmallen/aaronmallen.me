# frozen_string_literal: true

module Analytics
  module Queries
    class SummaryBetween
      KEYS = { countries: :country_code, paths: :path, referrers: :host }.freeze
      RANKS = { countries: :visitors, paths: :views, referrers: :visitors }.freeze
      SUMS = {
        countries: %i[views visitors].freeze,
        paths: %i[views visitors read_seconds bounces].freeze,
        referrers: %i[views visitors].freeze,
      }.freeze
      TOTALS = %i[views visitors read_seconds].freeze
      ZERO_DAY = { views: 0, visitors: 0 }.freeze

      include Deps[event_repo: "repos.analytics_event_repo", rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:)
        live = unrolled(from, to)

        {
          countries: ranked(:countries, rollup_repo.countries(from:, to:), live),
          days: days(from, to, live),
          paths: ranked(:paths, rollup_repo.top_paths(from:, to:), live),
          referrers: ranked(:referrers, rollup_repo.referrers(from:, to:), live),
          totals: totals(from, to, live),
        }
      end

      private

      def combine(rows, key, fields)
        rows.each_with_object({}) do |row, found|
          held = found[row[key]]
          found[row[key]] = held ? held.merge(row, fields.to_h { [it, sum(held[it], row[it])] }) : row
        end.values
      end

      def days(from, to, live)
        found = rollup_repo.days(from:, to:).to_h { [it.day, { views: it.views, visitors: it.visitors }] }
        found[live.day] = live.totals.to_h.slice(*ZERO_DAY.keys) if live

        (from..to).map { { day: it, **found.fetch(it, ZERO_DAY) } }
      end

      def ranked(name, rolled, live)
        key = KEYS.fetch(name)
        rank = RANKS.fetch(name)
        so_far = live ? live.public_send(name) : Blog::Constants::EMPTY_ARRAY

        combine((rolled + so_far).map(&:to_h), key, SUMS.fetch(name)).sort_by { standing(it, rank, key) }
      end

      def standing(row, rank, key) = [row[rank] ? 0 : 1, -row[rank].to_i, -row[:views], row[key].to_s]

      def sum(held, found) = held && found ? held + found : held || found

      def totals(from, to, live)
        found = rollup_repo.totals(from:, to:).to_h
        return found unless live

        TOTALS.to_h { [it, found.fetch(it) + live.totals.public_send(it)] }
      end

      def unrolled(from, to)
        today = Blog::TimeZone.today
        return unless (from..to).cover?(today) && rollup_repo.by_day(today).nil?

        event_repo.summary_for(today)
      end
    end
  end
end
