# frozen_string_literal: true

module Activity
  module Repos
    class ActivityQueries < Blog::DB::Repo
      NONE = Blog::Constants::EMPTY_ARRAY
      TYPES = Blog::Types::ActivityKind.values

      def between(from:, to:, limit: nil, **filters)
        found = narrowed(from:, to:, **filters).newest_first.with_tags

        found.limit(limit).to_a
      end

      def commit_totals(from:, to:, **filters)
        totalled = narrowed(from:, to:, **filters).commit_totals_by_repo

        totalled.to_a.to_h { [it.repo, it.to_h.except(:repo)] }
      end

      def contributor_choices = { agents: contributor_names(:agent), models: contributor_names(:model) }

      def counts(from:, to:, types: TYPES, **filters)
        found = narrowed(from:, to:, types:, **filters).counts_by_type.to_a.to_h { [it.type, it.count] }

        tally(found, types)
      end

      def counts_by_day(from:, to:, **filters)
        narrowed(from:, to:, **filters).counts_by_day.to_a.to_h { [it.occurred_on, it.count] }
      end

      def counts_by_month(from:, to:, types: TYPES, **filters)
        tallied = narrowed(from:, to:, types:, **filters).counts_by_month.to_a

        tallied.map(&:month).uniq.sort.reverse.to_h { [it, month_counts(tallied, it, types)] }
      end

      def day_count(from:, to:, **filters) = narrowed(from:, to:, **filters).day_count

      private

      def blank?(value) = value.to_s.strip.empty?

      def contributor_names(column) = task_contributors.named(column).pluck(column)

      def month_counts(tallied, month, types)
        tally(tallied.select { it.month == month }.to_h { [it.type, it.count] }, types)
      end

      def narrowed(from:, to:, types: TYPES, repos: NONE, text: nil, tags: NONE, **credits)
        found = activities.between(from, to).with_types(types).credited(**credits)
        found = found.in_repo(repos) unless repos.empty?
        found = found.tagged(tags) unless tags.empty?

        blank?(text) ? found : found.matching(text.to_s.strip)
      end

      def tally(found, types) = types.to_h { [it, found.fetch(it, 0)] }
    end
  end
end
