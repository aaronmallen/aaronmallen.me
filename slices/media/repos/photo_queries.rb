# frozen_string_literal: true

module Media
  module Repos
    class PhotoQueries < DB::Repo
      def by_key(key) = photos.with_keys(key).one

      def published(key) = photos.published.with_keys(key).one

      def unclaimed_before(at) = photos.unclaimed.uploaded_before(at).to_a
    end
  end
end
