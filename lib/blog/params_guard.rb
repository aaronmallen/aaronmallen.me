# frozen_string_literal: true

require "hanami/middleware/public_errors_app"
require "rack"

module Blog
  class ParamsGuard
    AUTHORIZATION = "HTTP_AUTHORIZATION"
    BODY_LIMIT = 1024 * 1024
    CHUNK = 64 * 1024
    FORM_TYPES = ::Rack::Request::FORM_DATA_MEDIA_TYPES
    MULTIPART = "multipart/form-data"
    PUBLIC = "public"
    PULSE_LIMIT = 8 * 1024
    SHARE_UPLOAD_LIMIT = 100 * 1024 * 1024
    UPLOAD_LIMIT = 25 * 1024 * 1024
    ENCODED_UPLOAD_LIMIT = UPLOAD_LIMIT * 4 / 3
    LIMITS = {
      "/admin/files" => { limit: SHARE_UPLOAD_LIMIT, auth: :session, multipart: true },
      "/admin/mail/draft" => { limit: BODY_LIMIT, auth: :session, multipart: true },
      "/admin/mail/send" => { limit: UPLOAD_LIMIT, auth: :session, multipart: true },
      "/admin/photos" => { limit: UPLOAD_LIMIT, auth: :session, multipart: true },
      "/api/v1/photos" => { limit: ENCODED_UPLOAD_LIMIT, auth: :api_token, multipart: false },
      "/api/v1/share_groups" => { limit: ENCODED_UPLOAD_LIMIT, auth: :api_token, multipart: false },
      "/api/v1/shares" => { limit: ENCODED_UPLOAD_LIMIT, auth: :api_token, multipart: false },
      "/mcp" => { limit: ENCODED_UPLOAD_LIMIT, auth: :header, multipart: false },
      "/pulse" => { limit: PULSE_LIMIT, multipart: false },
    }.freeze

    def initialize(app, session_reader, token_reader)
      @app = app
      @session_reader = session_reader
      @token_reader = token_reader
      @errors_app = Hanami::Middleware::PublicErrorsApp.new(Hanami.app.root.join(PUBLIC))
    end

    def call(env)
      status = refusal(::Rack::Request.new(env))
      return @app.call(env) unless status

      @errors_app.call(env.merge(::Rack::PATH_INFO => "/#{::Rack::Utils.status_code(status)}"))
    end

    private

    def authorized?(request, auth)
      case auth
        in :api_token then live_token?(request)
        in :header then !request.get_header(AUTHORIZATION).to_s.empty?
        in :session then signed_in?(request)
        in nil then true
      end
    end

    def form(request) = FORM_TYPES.include?(request.media_type) ? request.POST : Blog::Constants::EMPTY_HASH

    def limit(request)
      rule = rule(request)
      rule && authorized?(request, rule[:auth]) ? rule[:limit] : BODY_LIMIT
    end

    def live_token?(request)
      match = Blog::Constants::BEARER.match(request.get_header(AUTHORIZATION).to_s)
      match && @token_reader.call(match[:token])
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
      if oversized?(request) then :content_too_large
      elsif request.media_type == MULTIPART && !upload?(request) then :unsupported_media_type
      elsif !readable?(request) then :bad_request
      end
    end

    def rule(request) = request.post? ? LIMITS[request.path_info] : nil

    def signed_in?(request)
      @session_reader.call(::Rack::Request.new(request.env.dup)).signed_in?
    end

    def upload?(request) = rule(request)&.fetch(:multipart)

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
