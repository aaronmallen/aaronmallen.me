# frozen_string_literal: true

module Media
  module Operations
    class SweepPhotos
      GRACE = 24 * 60 * 60

      include Deps[photo_repo: "repos.photo_repo", purge_photos: "operations.purge_photos"]

      def call(at: Time.now) = purge_photos.call(photo_repo.unclaimed_before(at - GRACE))
    end
  end
end
