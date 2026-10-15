# frozen_string_literal: true

module Public
  module Actions
    module Media
      class Show < Action
        CACHE_PUBLISHED = "public, max-age=31536000, s-maxage=86400, immutable"
        CACHE_MISS = "public, max-age=60"
        CACHE_NEVER = "private, no-store"
        NOT_FOUND = 404

        include Deps[photo_queries: "media.repos.photo_queries", store: "media_store.client"]

        config.formats.clear

        def handle(request, response)
          published = published(request.params[:key])
          key = stored_key(request, published)
          photo = fetch(key) if key
          response.headers.delete("Vary")
          return miss(response) unless photo

          serve(response, photo, published ? CACHE_PUBLISHED : CACHE_NEVER)
        end

        private

        def fetch(key)
          store.get(key)
        rescue ObjectStore::Client::Error
          nil
        end

        def miss(response)
          response.headers["Cache-Control"] = CACHE_MISS
          response.status = NOT_FOUND
          response.body = Blog::Constants::EMPTY_STRING
        end

        def photo_key?(key) = Blog::Types::PhotoKey.valid?(key)

        def published(key) = photo_key?(key) ? photo_queries.published(key) : nil

        def serve(response, photo, cache_control)
          response.headers["Cache-Control"] = cache_control
          response.content_type = photo.content_type
          response.body = photo.body
        end

        def stored_key(request, published)
          key, width = request.params.to_h.values_at(:key, :width)
          return width_key(published, width.to_i) if width

          key if published || (photo_key?(key) && session_reader.call(request).signed_in?)
        end

        def width_key(published, width) = published&.widths&.include?(width) ? published.variant_key(width) : nil
      end
    end
  end
end
