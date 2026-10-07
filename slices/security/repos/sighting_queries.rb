# frozen_string_literal: true

module Security
  module Repos
    class SightingQueries < DB::Repo
      def newest_first = sightings.newest_first.to_a
    end
  end
end
