# frozen_string_literal: true

module Suggestions
  module Repos
    class SuggestionRepo < Blog::DB::Repo
      ACCEPTED = "accepted"
      EDIT_FIELDS = %i[original replacement reason part].freeze
      PENDING = "pending"
      REJECTED = "rejected"
      STALE = "stale"
      OPEN = [PENDING, STALE].freeze

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }

      def accept(ids) = mark(ids, ACCEPTED, from: PENDING)

      def by_id(id) = with_edits.by_pk(id).one

      def created_between(from:, to:)
        found = with_edits.created_since(Blog::TimeZone.day_start(from))
        found = found.created_before(Blog::TimeZone.day_start(to + 1))

        found.newest_first.to_a
      end

      def for_post(post_id) = latest(with_edits.for_post(post_id))

      def for_social_post(social_post_id) = latest(with_edits.for_social_post(social_post_id))

      def lock_pending(ids) = suggestion_edits.with_ids(ids).with_status(PENDING).in_order.lock.to_a

      def mark_stale(ids) = mark(ids, STALE, from: PENDING)

      def open_counts_for_social_posts(social_post_ids)
        latest = latest_ids_for_social_posts(social_post_ids)
        counts = open_counts(latest.values)

        latest.filter_map { |social_post_id, id| [social_post_id, counts[id]] if counts[id] }.to_h
      end

      def reject(ids) = mark(ids, REJECTED, from: OPEN)

      def replace_for_post(post_id, edits) = replace(edits, post_id:)

      def replace_for_social_post(social_post_id, edits) = replace(edits, social_post_id:)

      private

      def drop_open(target)
        targeted = suggestions.for_target(**target)

        suggestion_edits.for_suggestions(targeted.ids).with_status(OPEN).delete
        targeted.without_edits(suggestion_edits.suggestion_ids).delete
      end

      def insert_edits(suggestion_id, edits)
        rows = edits.each_with_index.map do |edit, index|
          { **EDIT_FIELDS.to_h { [it, edit[it]] }, suggestion_id:, position: index + 1 }
        end

        suggestion_edits.stamped(:create, result: :many).call(rows)
      end

      def latest(relation) = relation.newest_first.limit(1).one

      def latest_ids_for_social_posts(social_post_ids)
        return Dry::Core::Constants::EMPTY_HASH if social_post_ids.empty?

        suggestions.for_social_posts(social_post_ids).latest_ids_by_social_post
      end

      def mark(ids, status, from:)
        listed = Array(ids)
        return Dry::Core::Constants::EMPTY_ARRAY if listed.empty?

        suggestion_edits.with_ids(listed).with_status(from).mark(status).sort_by(&:position)
      end

      def open_counts(suggestion_ids)
        return Dry::Core::Constants::EMPTY_HASH if suggestion_ids.empty?

        counts = suggestion_edits.for_suggestions(suggestion_ids).with_status(OPEN).counts_by_suggestion

        counts.to_a.to_h { [it.suggestion_id, it.count] }
      end

      def replace(edits, **target)
        suggestion = transaction do
          drop_open(target)
          created = create(**target)
          insert_edits(created.id, edits)
          created
        end

        by_id(suggestion.id)
      end

      def with_edits = suggestions.combine(:suggestion_edits)
    end
  end
end
