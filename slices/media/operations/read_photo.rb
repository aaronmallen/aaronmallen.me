# frozen_string_literal: true

module Media
  module Operations
    class ReadPhoto < Blog::Operation
      KEY = %r{([^/?#]+)/?(?:[?#].*)?\z}

      Read = Data.define(:photo, :stored)

      include Deps["store.client", photo_repo: "repos.photo_repo"]

      def call(reference)
        key = reference.strip[KEY, 1] || reference
        photo = step find(key)
        stored = step fetch(photo.key)

        Read.new(photo:, stored:)
      end

      private

      def fetch(key)
        stored = client.get(key) if client.configured?
        stored ? Success(stored) : Failure([:unavailable])
      rescue Store::Client::Error
        Failure([:unavailable])
      end

      def find(key)
        photo = photo_repo.by_key(key)
        photo ? Success(photo) : Failure([:missing, key])
      end
    end
  end
end
