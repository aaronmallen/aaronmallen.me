# frozen_string_literal: true

require "hanami/middleware/public_errors_app"
require "rack"

module Blog
  class ParamsGuard
    BAD_REQUEST = 400
    BODY_LIMIT = 1024 * 1024
    FORM_TYPES = ::Rack::Request::FORM_DATA_MEDIA_TYPES
    MAIL_DRAFT_PATH = "/admin/mail/draft"
    MAIL_SEND_PATH = "/admin/mail/send"
    MULTIPART = "multipart/form-data"
    PUBLIC = "public"
    SHARE_UPLOAD_LIMIT = 100 * 1024 * 1024
    SHARE_UPLOAD_PATH = "/admin/files"
    TOO_LARGE = 413
    UNSUPPORTED = 415
    UPLOAD_LIMIT = 25 * 1024 * 1024
    ENCODED_UPLOAD_LIMIT = UPLOAD_LIMIT * 4 / 3
    UPLOAD_PATH = "/admin/photos"
    UPLOAD_LIMITS = {
      UPLOAD_PATH => UPLOAD_LIMIT,
      "/api/v1/photos" => ENCODED_UPLOAD_LIMIT,
      "/mcp" => ENCODED_UPLOAD_LIMIT,
      SHARE_UPLOAD_PATH => SHARE_UPLOAD_LIMIT,
      MAIL_SEND_PATH => UPLOAD_LIMIT,
    }.freeze
    UPLOAD_PATHS = [UPLOAD_PATH, SHARE_UPLOAD_PATH, MAIL_SEND_PATH, MAIL_DRAFT_PATH].freeze

    def initialize(app, session_reader)
      @app = app
      @session_reader = session_reader
      @errors_app = Hanami::Middleware::PublicErrorsApp.new(Hanami.app.root.join(PUBLIC))
    end

    def call(env)
      status = refusal(::Rack::Request.new(env))
      return @app.call(env) unless status

      @errors_app.call(env.merge(::Rack::PATH_INFO => "/#{status}"))
    end

    private

    def form(request) = FORM_TYPES.include?(request.media_type) ? request.POST : Blog::Constants::EMPTY_HASH

    def limit(request)
      return BODY_LIMIT unless request.post?
      return BODY_LIMIT if UPLOAD_PATHS.include?(request.path_info) && !signed_in?(request)

      UPLOAD_LIMITS.fetch(request.path_info, BODY_LIMIT)
    end

    def readable?(request)
      [::Rack::Utils.unescape_path(request.path_info), request.GET, form(request)].all? { utf8?(it) }
    rescue ::Rack::BadRequest
      false
    end

    def refusal(request)
      if request.content_length.to_i > limit(request) then TOO_LARGE
      elsif request.media_type == MULTIPART && !upload?(request) then UNSUPPORTED
      elsif !readable?(request) then BAD_REQUEST
      end
    end

    def signed_in?(request)
      @session_reader.call(::Rack::Request.new(request.env.dup)).signed_in?
    end

    def upload?(request) = request.post? && UPLOAD_PATHS.include?(request.path_info)

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
