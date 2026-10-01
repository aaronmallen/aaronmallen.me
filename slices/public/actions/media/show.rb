# frozen_string_literal: true

module Public
  module Actions
    module Media
      class Show < Action
        CACHE_FOREVER = "public, max-age=31536000, immutable"
        NOT_FOUND = 404

        include Deps[store: "media.store.client"]

        config.formats.clear

        def handle(request, response)
          photo = fetch(request.params[:key])
          halt NOT_FOUND, Blog::Constants::EMPTY_STRING unless photo

          response.headers.delete("Vary")
          response.headers["Cache-Control"] = CACHE_FOREVER
          response.content_type = photo.content_type
          response.body = photo.body
        end

        private

        def fetch(key)
          store.get(key)
        rescue ::Media::Store::Client::Error
          nil
        end
      end
    end
  end
end
