# frozen_string_literal: true

module Media
  module Jobs
    class SweepPhotos < Blog::ScheduledJob
      include Deps[sweep_photos: "operations.sweep_photos"]

      def perform = sweep_photos.call
    end
  end
end
