# frozen_string_literal: true

require "hanami/middleware/public_errors_app"
require "rack"

module Blog
  class ParamsGuard
    AUTHORIZATION = "HTTP_AUTHORIZATION"
    BAD_REQUEST = 400
    BODY_LIMIT = 1024 * 1024
    CHUNK = 64 * 1024
    FORM_TYPES = ::Rack::Request::FORM_DATA_MEDIA_TYPES
    MULTIPART = "multipart/form-data"
    PUBLIC = "public"
    SHARE_UPLOAD_LIMIT = 100 * 1024 * 1024
    TOO_LARGE = 413
    UNSUPPORTED = 415
    UPLOAD_LIMIT = 25 * 1024 * 1024
    ENCODED_UPLOAD_LIMIT = UPLOAD_LIMIT * 4 / 3
    UPLOADS = {
      "/admin/files" => { limit: SHARE_UPLOAD_LIMIT, auth: :session, multipart: true },
      "/admin/mail/draft" => { limit: BODY_LIMIT, auth: :session, multipart: true },
      "/admin/mail/send" => { limit: UPLOAD_LIMIT, auth: :session, multipart: true },
      "/admin/photos" => { limit: UPLOAD_LIMIT, auth: :session, multipart: true },
      "/api/v1/photos" => { limit: ENCODED_UPLOAD_LIMIT, auth: :token, multipart: false },
      "/mcp" => { limit: ENCODED_UPLOAD_LIMIT, auth: :token, multipart: false },
    }.freeze

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

    def authorized?(request, auth)
      auth == :token ? !request.get_header(AUTHORIZATION).to_s.empty? : signed_in?(request)
    end

    def form(request) = FORM_TYPES.include?(request.media_type) ? request.POST : Blog::Constants::EMPTY_HASH

    def limit(request)
      rule = upload(request)
      rule && authorized?(request, rule[:auth]) ? rule[:limit] : BODY_LIMIT
    end

    def oversized?(request)
      limit = limit(request)
      return request.content_length.to_i > limit if request.content_length

      request.body ? read_size(request.body, limit) > limit : false
    end

    def read_size(input, limit)
      size = 0
      while (chunk = input.read(CHUNK))
        size += chunk.bytesize
        break if size > limit
      end
      input.rewind
      size
    end

    def readable?(request)
      [::Rack::Utils.unescape_path(request.path_info), request.GET, form(request)].all? { utf8?(it) }
    rescue ::Rack::BadRequest
      false
    end

    def refusal(request)
      if oversized?(request) then TOO_LARGE
      elsif request.media_type == MULTIPART && !upload?(request) then UNSUPPORTED
      elsif !readable?(request) then BAD_REQUEST
      end
    end

    def signed_in?(request)
      @session_reader.call(::Rack::Request.new(request.env.dup)).signed_in?
    end

    def upload(request) = request.post? ? UPLOADS[request.path_info] : nil

    def upload?(request) = upload(request)&.fetch(:multipart)

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
