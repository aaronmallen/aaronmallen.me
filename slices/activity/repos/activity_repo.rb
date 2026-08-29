# frozen_string_literal: true

module Activity
  module Repos
    class ActivityRepo < Blog::DB::Repo
      NONE = Dry::Core::Constants::EMPTY_ARRAY
      TYPES = Blog::Types::ActivityKind.values

      def between(from:, to:, types: TYPES, repos: NONE, text: nil, tags: NONE, limit: nil)
        found = narrowed(from:, to:, types:, repos:, text:, tags:).newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def commit_totals(from:, to:, types: TYPES, repos: NONE, text: nil, tags: NONE)
        totalled = narrowed(from:, to:, types:, repos:, text:, tags:).commit_totals_by_repo

        totalled.to_a.to_h { [it.repo, it.to_h.except(:repo)] }
      end

      def counts(from:, to:, types: TYPES, repos: NONE, text: nil, tags: NONE)
        found = narrowed(from:, to:, types:, repos:, text:, tags:).counts_by_type.to_a.to_h { [it.type, it.count] }

        tally(found, types)
      end

      def counts_by_month(from:, to:, types: TYPES, repos: NONE, text: nil, tags: NONE)
        tallied = narrowed(from:, to:, types:, repos:, text:, tags:).counts_by_month.to_a

        tallied.map(&:month).uniq.sort.reverse.to_h { [it, month_counts(tallied, it, types)] }
      end

      private

      def blank?(value) = value.to_s.strip.empty?

      def month_counts(tallied, month, types)
        tally(tallied.select { it.month == month }.to_h { [it.type, it.count] }, types)
      end

      def narrowed(from:, to:, types:, repos:, text:, tags:)
        found = activities.between(from, to).with_types(types)
        found = found.in_repo(repos) unless repos.empty?
        found = found.tagged(tags) unless tags.empty?

        blank?(text) ? found : found.matching(text.to_s.strip)
      end

      def tally(found, types) = types.to_h { [it, found.fetch(it, 0)] }
    end
  end
end
