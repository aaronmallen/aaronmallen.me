# frozen_string_literal: true

module Security
  module Repos
    class SightingMutations < DB::Repo
      def sight(at: Time.now, **row) = sightings.sight(row, at:)
    end
  end
end
