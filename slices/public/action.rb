# auto_register: false
# frozen_string_literal: true

module Public
  class Action < Blog::Action
    ANY_MEDIA_TYPE = "*/*"
    FORBIDDEN = 403
    NOT_MODIFIED_HEADERS = %w[cache-control etag vary].freeze
    OK = 200
    PERSONAL_COOKIES = [Blog::SessionCookie::KEY, Blog::UI::Layouts::Application::THEME_COOKIE].freeze
    SAME_ORIGIN_FETCHES = %w[none same-origin].freeze
    SHARED_CACHE_LIFETIME = 300

    include Deps[session_reader: "admin.auth.session_reader", version_atom_feed: "operations.version_atom_feed"]

    config.formats.accept :html

    before :set_cache_policy

    def self.answer_any_accept(format = :html, media_type = Hanami::Action::Mime::TYPES.fetch(format))
      config.formats.register(
        format, media_type,
        accept_types: [ANY_MEDIA_TYPE], content_types: ::Rack::Request::FORM_DATA_MEDIA_TYPES,
      )
    end

    def self.share_with_caches = after(:share_with_caches)

    private

    def cross_site?(request)
      fetch_site = request.get_header("HTTP_SEC_FETCH_SITE")
      return !SAME_ORIGIN_FETCHES.include?(fetch_site) if fetch_site

      origin = request.get_header("HTTP_ORIGIN")
      !origin.nil? && origin != Blog::Site.origin
    end

    def halt_if_feed_unchanged(request, response, version)
      etag = version.etag
      last_modified = version.last_modified
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

    def share_with_caches(request, response)
      return unless response.status == OK && !response.headers.key?(CACHE_CONTROL)
      return if request.cookies.keys.intersect?(PERSONAL_COOKIES)

      response.cache_control(:public, max_age: 0, s_maxage: SHARED_CACHE_LIFETIME)
    end

    def version_feed_or_halt(request, response, posts)
      version = version_atom_feed.call(posts)
      halt_if_feed_unchanged(request, response, version)
      version
    end
  end
end
