# frozen_string_literal: true

module Media
  module Operations
    class SweepPhotos
      GRACE = 24 * 60 * 60

      include Deps[photo_queries: "repos.photo_queries", purge_photos: "operations.purge_photos"]

      def call(at: Time.now) = purge_photos.call(photo_queries.unclaimed_before(at - GRACE))
    end
  end
end
