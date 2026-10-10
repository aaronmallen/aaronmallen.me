# frozen_string_literal: true

module Security
  module Repos
    class SightingMutations < Blog::DB::Repo
      def delete_last_seen_before(time) = sightings.last_seen_before(time).delete

      def sight(at: Time.now, **row) = sightings.sight(row, at:)
    end
  end
end
