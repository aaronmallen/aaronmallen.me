# frozen_string_literal: true

module Shares
  module Relations
    class HeldTitleFetches < Blog::DB::Relation
      schema :held_title_fetches, infer: true

      def hold(short_link_id) = dataset.insert_conflict.insert(short_link_id:)

      def oldest_first = order(self[:id].asc)
    end
  end
end
