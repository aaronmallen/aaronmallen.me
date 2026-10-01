# frozen_string_literal: true

module Public
  module Actions
    module Media
      class Show < Action
        CACHE_FOREVER = "public, max-age=31536000, immutable"
        CACHE_MISS = "public, max-age=60"
        NOT_FOUND = 404

        include Deps[store: "media.store.client"]

        config.formats.clear

        def handle(request, response)
          photo = fetch(request.params[:key])
          response.headers.delete("Vary")
          return miss(response) unless photo

          response.headers["Cache-Control"] = CACHE_FOREVER
          response.content_type = photo.content_type
          response.body = photo.body
        end

        private

        def fetch(key)
          store.get(key) if ::Media::PhotoType::KEY.match?(key)
        rescue ::Media::Store::Client::Error
          nil
        end

        def miss(response)
          response.headers["Cache-Control"] = CACHE_MISS
          response.status = NOT_FOUND
          response.body = Blog::Constants::EMPTY_STRING
        end
      end
    end
  end
end
