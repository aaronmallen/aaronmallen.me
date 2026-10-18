# frozen_string_literal: true

module Shares
  class Preview
    include Deps[client: "share_store.client"]

    def call(request, file)
      return unless file.preview_key && request.query_string == Server::PREVIEW

      stored = client.get(file.preview_key)
      stored && [200, headers(stored), request.head? ? [] : [stored.body]]
    end

    private

    def headers(stored)
      Server::FILE_HEADERS.merge("content-length" => stored.body.bytesize.to_s, "content-type" => stored.content_type)
    end
  end
end
