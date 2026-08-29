# frozen_string_literal: true

require "uri"

module Blog
  module Site
    ROOT = "/"
    WRITING = "/writing"

    module_function

    def base_url = Hanami.app.config.base_url

    def origin = URI(url).origin

    def url(path = ROOT) = URI.join(base_url, path).to_s
  end
end
