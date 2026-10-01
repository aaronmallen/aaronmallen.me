# frozen_string_literal: true

module Media
  module Jobs
    class SweepPhotos < Blog::Job
      include Deps[sweep_photos: "operations.sweep_photos"]

      sidekiq_options retry: false

      def perform = sweep_photos.call
    end
  end
end
