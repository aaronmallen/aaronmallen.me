# frozen_string_literal: true

require "erb"
require "zip_kit"

module Shares
  class Server
    CODE_PATH = %r{\A/(?<code>[^/.]+)(?:/(?<id>[1-9][0-9]*)|(?<zip>\.zip))?\z}
    FILE_POLICY = "sandbox; default-src 'none'; style-src 'unsafe-inline'"
    FILE_HEADERS = { "content-security-policy" => FILE_POLICY, "x-content-type-options" => "nosniff" }.freeze
    PAGE_HEADERS = {
      "content-security-policy" => "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'",
      "content-type" => "text/html; charset=utf-8",
      "x-content-type-options" => "nosniff",
    }.freeze
    PROBE_END = 1
    INLINE_TYPE = %r{\A(?:(?:image/(?!svg)|video/|audio/)[\w.+-]+|application/pdf)\z}i
    PREVIEW = "preview"
    UNSAFE_FILENAME = /[^\x20-\x7e]|["\\]/

    include Deps[
      client: "share_store.client", share_group_mutations: "repos.share_group_mutations",
      share_group_queries: "repos.share_group_queries", share_mutations: "repos.share_mutations",
      preview: "preview", share_queries: "repos.share_queries", settings: "settings",
      short_code_queries: "repos.short_code_queries", short_link_mutations: "repos.short_link_mutations",
    ]

    def initialize(**)
      super
      @transfers = Transfers.new(settings)
    end

    def call(env)
      request = ::Rack::Request.new(env)
      code, id, zip = requested_path(request)
      return [404, {}, []] unless code
      return zip(request, code) if zip

      id ? group_file(request, code, Integer(id)) : answer(request, code)
    end

    private

    def answer(request, code)
      destination = clicked?(request) && short_link_mutations.click(code)
      return redirect(destination) if destination

      owner = short_code_queries.owner(code) || {}
      return share(request, owner[:share_id]) if owner[:share_id]
      return page(request, owner[:share_group_id]) if owner[:share_group_id]

      owner[:destination] ? redirect(owner[:destination]) : [404, {}, []]
    end

    def clicked?(request) = !request.head? && !Blog::Helpers::Bot.match?(request.user_agent)

    def counted?(request, range = nil)
      return false if request.head? || request.query_string == PREVIEW
      return false if range && (range.begin.positive? || range.end <= PROBE_END)

      !Blog::Helpers::Bot.match?(request.user_agent)
    end

    def disposition(share) = named(INLINE_TYPE.match?(share.content_type) ? "inline" : "attachment", share.filename)

    def entry_name(filename) = filename.tr("/", "_").sub(/\A\.\.?\z/) { "_" * it.size }

    def group_file(request, code, id)
      stream(request, share_group_queries.file_by_code(code, id)) { share_group_mutations.count_file_download(id) }
    end

    def named(kind, filename)
      fallback = filename.gsub(UNSAFE_FILENAME, "_")
      "#{kind}; filename=\"#{fallback}\"; filename*=UTF-8''#{ERB::Util.url_encode(filename)}"
    end

    def note(request, range) = counted?(request, range) && yield

    def page(request, id)
      group = share_group_queries.find(id)
      return [404, {}, []] unless group

      share_group_mutations.count_view(group.id) if counted?(request)
      html = GroupPage.new(group, settings).call
      [200, PAGE_HEADERS.merge("content-length" => html.bytesize.to_s), request.head? ? [] : [html]]
    end

    def partial(share, range)
      share_headers(share).merge(
        "content-length" => range.size.to_s, "content-range" => "bytes #{range.begin}-#{range.end}/#{share.byte_size}",
      )
    end

    def redirect(destination) = [302, { "location" => destination }, []]

    def requested_path(request)
      path = CODE_PATH.match(request.path_info)
      path.captures if path && (request.get? || request.head?) && Blog::Types::ShortCode.valid?(path[:code])
    end

    def serve(request, share, &)
      ranges = ::Rack::Utils.get_byte_ranges(request.get_header("HTTP_RANGE"), share.byte_size)
      return [416, { "content-range" => "bytes */#{share.byte_size}" }, []] if ranges && ranges.empty?

      range = ranges.first if ranges&.one?
      note(request, range, &)
      body = request.head? ? [] : ObjectStore::Body.new(client, share.key, range)
      range ? [206, partial(share, range), body] : [200, share_headers(share), body]
    end

    def share(request, id) = stream(request, share_queries.find(id)) { share_mutations.count_download(id) }

    def share_headers(share)
      FILE_HEADERS.merge(
        "accept-ranges" => "bytes", "content-disposition" => disposition(share),
        "content-length" => share.byte_size.to_s, "content-type" => share.content_type,
      )
    end

    def stream(request, file, &)
      return [404, {}, []] unless file
      return [503, {}, []] unless client.configured?

      preview.call(request, file) || @transfers.call do
        client.exists?(file.key) ? serve(request, file, &) : [404, {}, []]
      end
    end

    def zip(request, code)
      group = share_group_queries.by_code(code)
      return [404, {}, []] unless group
      return [503, {}, []] unless client.configured?

      @transfers.call do
        share_group_mutations.count_zip_download(group.id) if counted?(request)
        [200, zip_headers(group), request.head? ? [] : zip_body(group.share_group_files)]
      end
    end

    def zip_body(files)
      ZipKit::OutputEnumerator.new(auto_rename_duplicate_filenames: true) do |zip|
        files.each do |file|
          zip.write_file(entry_name(file.filename)) { |sink| client.stream(file.key) { sink << it } }
        end
      end
    end

    def zip_headers(group)
      name = "#{group.name || group.code}.zip"
      FILE_HEADERS.merge("content-disposition" => named("attachment", name), "content-type" => "application/zip")
    end
  end
end
