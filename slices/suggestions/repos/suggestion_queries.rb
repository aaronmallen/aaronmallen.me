# frozen_string_literal: true

module Suggestions
  module Repos
    class SuggestionQueries < DB::Repo
      OPEN = [Blog::Types::SuggestionEditStatus["pending"], Blog::Types::SuggestionEditStatus["stale"]].freeze

      def by_id(id) = with_edits.by_pk(id).one

      def created_between(from:, to:, page:)
        found = with_edits.created_since(Blog::TimeZone.day_start(from))
        found = found.created_before(Blog::TimeZone.day_start(to + 1))

        page.fill(found.newest_first.paged(page).to_a)
      end

      def for_post(post_id) = latest(with_edits.for_post(post_id))

      def for_social_post(social_post_id) = latest(with_edits.for_social_post(social_post_id))

      def open_counts_for_social_posts(social_post_ids)
        latest = latest_ids_for_social_posts(social_post_ids)
        counts = open_counts(latest.values)

        latest.filter_map { |social_post_id, id| [social_post_id, counts[id]] if counts[id] }.to_h
      end

      private

      def latest(relation) = relation.newest_first.limit(1).one

      def latest_ids_for_social_posts(social_post_ids)
        return Blog::Constants::EMPTY_HASH if social_post_ids.empty?

        suggestions.for_social_posts(social_post_ids).latest_ids_by_social_post
      end

      def open_counts(suggestion_ids)
        return Blog::Constants::EMPTY_HASH if suggestion_ids.empty?

        counts = suggestion_edits.for_suggestions(suggestion_ids).with_status(OPEN).counts_by_suggestion

        counts.to_a.to_h { [it.suggestion_id, it.count] }
      end

      def with_edits = suggestions.combine(:suggestion_edits)
    end
  end
end
