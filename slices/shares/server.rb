# frozen_string_literal: true

require "erb"

module Shares
  class Server
    Body = Data.define(:client, :key, :range) do
      def each(&) = client.stream(key, range: range && "bytes=#{range.begin}-#{range.end}", &)
    end

    CODE_PATH = %r{\A/(?<code>[^/]+)\z}
    PROBE_END = 1
    INLINE_TYPE = %r{\A(?:(?:image/(?!svg)|video/|audio/)|application/pdf\z)}i
    PREVIEW = "preview"
    UNSAFE_FILENAME = /[^\x20-\x7e]|["\\]/

    include Deps[
      client: "share_store.client", share_mutations: "repos.share_mutations", share_queries: "repos.share_queries",
    ]

    def call(env)
      request = ::Rack::Request.new(env)
      share = find(request)
      return [404, {}, []] unless share
      return [503, {}, []] unless client.configured?

      serve(request, share)
    end

    private

    def count(request, share, range)
      return if request.head? || request.query_string == PREVIEW
      return if range && (range.begin.positive? || range.end <= PROBE_END)
      return if Blog::Helpers::Bot.match?(request.user_agent)

      share_mutations.count_download(share.id)
    end

    def disposition(share)
      kind = INLINE_TYPE.match?(share.content_type) ? "inline" : "attachment"
      fallback = share.filename.gsub(UNSAFE_FILENAME, "_")
      "#{kind}; filename=\"#{fallback}\"; filename*=UTF-8''#{ERB::Util.url_encode(share.filename)}"
    end

    def find(request)
      code = CODE_PATH.match(request.path_info)&.[](:code)
      return unless code && (request.get? || request.head?) && Blog::Types::ShortCode.valid?(code)

      share_queries.by_code(code)
    end

    def partial(share, range)
      share_headers(share).merge(
        "content-length" => range.size.to_s, "content-range" => "bytes #{range.begin}-#{range.end}/#{share.byte_size}",
      )
    end

    def serve(request, share)
      ranges = ::Rack::Utils.get_byte_ranges(request.get_header("HTTP_RANGE"), share.byte_size)
      return [416, { "content-range" => "bytes */#{share.byte_size}" }, []] if ranges && ranges.empty?

      range = ranges.first if ranges&.one?
      count(request, share, range)
      body = request.head? ? [] : Body.new(client, share.key, range)
      range ? [206, partial(share, range), body] : [200, share_headers(share), body]
    end

    def share_headers(share)
      {
        "accept-ranges" => "bytes",
        "content-disposition" => disposition(share),
        "content-length" => share.byte_size.to_s,
        "content-type" => share.content_type,
        "x-content-type-options" => "nosniff",
      }
    end
  end
end
