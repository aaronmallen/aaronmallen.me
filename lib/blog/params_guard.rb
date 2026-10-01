# frozen_string_literal: true

require "hanami/middleware/public_errors_app"
require "rack"

module Blog
  class ParamsGuard
    BAD_REQUEST_PAGE = "/400"
    FORM_TYPES = ::Rack::Request::FORM_DATA_MEDIA_TYPES
    PUBLIC = "public"

    def initialize(app)
      @app = app
      @errors_app = Hanami::Middleware::PublicErrorsApp.new(Hanami.app.root.join(PUBLIC))
    end

    def call(env)
      return @app.call(env) if readable?(::Rack::Request.new(env))

      @errors_app.call(env.merge(::Rack::PATH_INFO => BAD_REQUEST_PAGE))
    end

    private

    def form(request) = FORM_TYPES.include?(request.media_type) ? request.POST : Blog::Constants::EMPTY_HASH

    def readable?(request)
      [::Rack::Utils.unescape_path(request.path_info), request.GET, form(request)].all? { utf8?(it) }
    rescue ::Rack::BadRequest
      false
    end

    def utf8?(value)
      case value
      when ::Hash then value.all? { |key, item| utf8?(key) && utf8?(item) }
      when ::Array then value.all? { utf8?(it) }
      when ::String then value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      else true
      end
    end
  end
end
