# frozen_string_literal: true

module Public
  module Actions
    module Media
      class Show < Action
        CACHE_PUBLISHED = "public, max-age=31536000, s-maxage=86400, immutable"
        CACHE_MISS = "public, max-age=60"
        CACHE_NEVER = "private, no-store"
        NOT_FOUND = 404

        include Deps[published_photo: "media.queries.published_photo", store: "media.store.client"]

        config.formats.clear

        def handle(request, response)
          key = request.params[:key]
          published = published?(key)
          photo = fetch(key) if published || session_reader.call(request).signed_in?
          response.headers.delete("Vary")
          return miss(response) unless photo

          serve(response, photo, published ? CACHE_PUBLISHED : CACHE_NEVER)
        end

        private

        def fetch(key)
          store.get(key) if photo_key?(key)
        rescue ::Media::Store::Client::Error
          nil
        end

        def miss(response)
          response.headers["Cache-Control"] = CACHE_MISS
          response.status = NOT_FOUND
          response.body = Blog::Constants::EMPTY_STRING
        end

        def photo_key?(key) = ::Media::PhotoType::KEY.match?(key)

        def published?(key) = photo_key?(key) && !published_photo.call(key).nil?

        def serve(response, photo, cache_control)
          response.headers["Cache-Control"] = cache_control
          response.content_type = photo.content_type
          response.body = photo.body
        end
      end
    end
  end
end
