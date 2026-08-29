# frozen_string_literal: true

module Suggestions
  module Relations
    class Suggestions < Blog::DB::Relation
      schema :suggestions, infer: true do
        associations do
          has_many :suggestion_edits, view: :in_order
        end
      end

      def created_before(time) = where { created_at < time }

      def created_since(time) = where { created_at >= time }

      def for_post(post_id) = for_target(post_id:)

      def for_social_post(social_post_id) = for_target(social_post_id:)

      def for_social_posts(social_post_ids) = where(social_post_id: social_post_ids)

      def for_target(**target) = where(**target)

      def ids = unordered.dataset.select(:id)

      def latest_ids_by_social_post
        newest = %i[created_at id].map { Sequel[:suggestions][it].desc }

        found = unordered.dataset.distinct(:social_post_id).order(:social_post_id, *newest)

        found.select_hash(:social_post_id, :id)
      end

      def newest_first = order(self[:created_at].desc, self[:id].desc)

      def without_edits(edited) = exclude(id: edited)
    end
  end
end
