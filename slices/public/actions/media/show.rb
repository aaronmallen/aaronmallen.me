# frozen_string_literal: true

module Public
  module Actions
    module Media
      class Show < Action
        CACHE_PUBLISHED = "public, max-age=31536000, s-maxage=86400, immutable"
        CACHE_MISS = "public, max-age=60"
        CACHE_PRIVATE = "private, max-age=3600"
        NOT_FOUND = 404
        NOT_MODIFIED = 304

        include Deps[photo_queries: "media.repos.photo_queries", store: "media_store.client"]

        config.formats.clear

        def handle(request, response)
          published = published(request.params[:key])
          key = stored_key(request, published)
          response.headers.delete("Vary")
          return miss(response) unless key

          validators(response, key, published)
          return not_modified(response) if fresh?(request, key)

          photo = fetch(key)
          photo ? serve(response, photo) : miss(response)
        end

        private

        def etag(key) = %("#{key}")

        def fetch(key)
          store.get(key)
        rescue ObjectStore::Client::Error
          nil
        end

        def fresh?(request, key)
          request.get_header("HTTP_IF_NONE_MATCH").to_s.split(",").any? do |tag|
            tag.strip.delete_prefix("W/") == etag(key)
          end
        end

        def miss(response)
          response.headers.delete("ETag")
          response.headers["Cache-Control"] = CACHE_MISS
          response.status = NOT_FOUND
          response.body = Blog::Constants::EMPTY_STRING
        end

        def not_modified(response)
          response.status = NOT_MODIFIED
          response.body = Blog::Constants::EMPTY_STRING
        end

        def photo_key?(key) = Blog::Types::PhotoKey.valid?(key)

        def published(key) = photo_key?(key) ? photo_queries.published(key) : nil

        def serve(response, photo)
          response.content_type = photo.content_type
          response.body = photo.body
        end

        def stored_key(request, published)
          key, width = request.params.to_h.values_at(:key, :width)
          return width_key(published, width.to_i) if width

          key if published || (photo_key?(key) && session_reader.call(request).signed_in?)
        end

        def validators(response, key, published)
          response.headers["Cache-Control"] = published ? CACHE_PUBLISHED : CACHE_PRIVATE
          response.headers["ETag"] = etag(key)
        end

        def width_key(published, width) = published&.widths&.include?(width) ? published.variant_key(width) : nil
      end
    end
  end
end
