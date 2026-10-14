# frozen_string_literal: true

require "erb"
require "zip_kit"

module Shares
  class Server
    Body = Data.define(:client, :key, :range) do
      def each(&) = client.stream(key, range: range && "bytes=#{range.begin}-#{range.end}", &)
    end

    CODE_PATH = %r{\A/(?<code>[^/.]+)(?:/(?<id>[1-9][0-9]*)|(?<zip>\.zip))?\z}
    PAGE_HEADERS = {
      "content-security-policy" => "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'",
      "content-type" => "text/html; charset=utf-8",
      "x-content-type-options" => "nosniff",
    }.freeze
    PROBE_END = 1
    INLINE_TYPE = %r{\A(?:(?:image/(?!svg)|video/|audio/)|application/pdf\z)}i
    PREVIEW = "preview"
    UNSAFE_FILENAME = /[^\x20-\x7e]|["\\]/

    include Deps[
      client: "share_store.client", share_group_mutations: "repos.share_group_mutations",
      share_group_queries: "repos.share_group_queries", share_mutations: "repos.share_mutations",
      share_queries: "repos.share_queries", settings: "settings",
      short_link_mutations: "repos.short_link_mutations", short_link_queries: "repos.short_link_queries",
    ]

    def call(env)
      request = ::Rack::Request.new(env)
      code, id, zip = requested_path(request)
      return [404, {}, []] unless code
      return zip(request, code) if zip

      id ? group_file(request, code, Integer(id)) : answer(request, code)
    end

    private

    def answer(request, code)
      share = share_queries.by_code(code)
      return stream(request, share) { share_mutations.count_download(share.id) } if share

      group = share_group_queries.by_code(code)
      return page(request, group) if group

      link = short_link_queries.by_code(code)
      link ? redirect(request, link) : [404, {}, []]
    end

    def counted?(request, range = nil)
      return false if request.head? || request.query_string == PREVIEW
      return false if range && (range.begin.positive? || range.end <= PROBE_END)

      !Blog::Helpers::Bot.match?(request.user_agent)
    end

    def disposition(share)
      kind = INLINE_TYPE.match?(share.content_type) ? "inline" : "attachment"
      fallback = share.filename.gsub(UNSAFE_FILENAME, "_")
      "#{kind}; filename=\"#{fallback}\"; filename*=UTF-8''#{ERB::Util.url_encode(share.filename)}"
    end

    def group_file(request, code, id)
      file = share_group_queries.by_code(code)&.share_group_files&.find { it.id == id }
      return [404, {}, []] unless file

      stream(request, file) { share_group_mutations.count_file_download(file.id) }
    end

    def note(request, range) = counted?(request, range) && yield

    def page(request, group)
      share_group_mutations.count_view(group.id) if counted?(request)
      html = GroupPage.new(group, settings).call
      [200, PAGE_HEADERS.merge("content-length" => html.bytesize.to_s), request.head? ? [] : [html]]
    end

    def partial(share, range)
      share_headers(share).merge(
        "content-length" => range.size.to_s, "content-range" => "bytes #{range.begin}-#{range.end}/#{share.byte_size}",
      )
    end

    def redirect(request, link)
      short_link_mutations.count_click(link.id) unless request.head? || Blog::Helpers::Bot.match?(request.user_agent)
      [302, { "location" => link.destination }, []]
    end

    def requested_path(request)
      path = CODE_PATH.match(request.path_info)
      path.captures if path && (request.get? || request.head?) && Blog::Types::ShortCode.valid?(path[:code])
    end

    def serve(request, share, &)
      ranges = ::Rack::Utils.get_byte_ranges(request.get_header("HTTP_RANGE"), share.byte_size)
      return [416, { "content-range" => "bytes */#{share.byte_size}" }, []] if ranges && ranges.empty?

      range = ranges.first if ranges&.one?
      note(request, range, &)
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

    def stream(request, file, &) = client.configured? ? serve(request, file, &) : [503, {}, []]

    def zip(request, code)
      group = share_group_queries.by_code(code)
      return [404, {}, []] unless group
      return [503, {}, []] unless client.configured?

      share_group_mutations.count_zip_download(group.id) if counted?(request)
      [200, zip_headers(group), request.head? ? [] : zip_body(group.share_group_files)]
    end

    def zip_body(files)
      ZipKit::OutputEnumerator.new(auto_rename_duplicate_filenames: true) do |zip|
        files.each { |file| zip.write_file(file.filename) { |sink| client.stream(file.key) { sink << it } } }
      end
    end

    def zip_headers(group)
      {
        "content-disposition" => "attachment; filename=\"#{group.code}.zip\"",
        "content-type" => "application/zip",
        "x-content-type-options" => "nosniff",
      }
    end
  end
end
