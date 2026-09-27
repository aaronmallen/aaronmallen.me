# auto_register: false
# frozen_string_literal: true

require "digest"

module Public
  class Action < Blog::Action
    ANY_MEDIA_TYPE = "*/*"
    FORBIDDEN = 403
    NOT_MODIFIED_HEADERS = %w[cache-control etag vary].freeze
    SAME_ORIGIN_FETCHES = %w[none same-origin].freeze

    include Deps[session_reader: "admin.auth.session_reader"]

    config.formats.accept :html

    before :set_cache_policy

    def self.answer_any_accept(format = :html)
      config.formats.register(
        format, Hanami::Action::Mime::TYPES.fetch(format),
        accept_types: [ANY_MEDIA_TYPE], content_types: ::Rack::Request::FORM_DATA_MEDIA_TYPES,
      )
    end

    private

    def cross_site?(request)
      fetch_site = request.get_header("HTTP_SEC_FETCH_SITE")
      return !SAME_ORIGIN_FETCHES.include?(fetch_site) if fetch_site

      origin = request.get_header("HTTP_ORIGIN")
      !origin.nil? && origin != Blog::Site.origin
    end

    def feed_etag(posts)
      versions = posts.map { "#{it.id}@#{it.changed_at.utc.iso8601(6)}" }
      %(W/"#{Digest::SHA256.hexdigest(versions.join(','))}")
    end

    def halt_if_feed_unchanged(request, response, posts)
      etag = feed_etag(posts)
      last_modified = posts.map(&:changed_at).max
      response.headers[LAST_MODIFIED] = last_modified.httpdate if last_modified
      return response.fresh(etag:) if request.get_header(IF_NONE_MATCH)

      response.fresh(etag:, last_modified:)
    end

    def keep_response_header?(header) = super || NOT_MODIFIED_HEADERS.include?(header.downcase)

    def refuse_cross_site(request, _response)
      halt FORBIDDEN if cross_site?(request)
    end

    def set_cache_policy(request, response)
      forbid_caching(request, response) if session_reader.call(request).signed_in?
    end
  end
end
