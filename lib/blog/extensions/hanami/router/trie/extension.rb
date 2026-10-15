# frozen_string_literal: true

require "blog/extensions"
require "hanami/router"

module Blog
  module Extensions
    module Hanami
      module Router
        module Trie
          module Extension
            def find(path)
              node = @root
              return unless segments_from(path).all? { |segment| node = node.get(segment) }

              node.capture(path)
            end

            private

            def segments_from(path) = path.split("/").drop(1)
          end
        end
      end
    end
  end
end

Blog::Extensions.apply(
  Hanami::Router::Trie,
  Blog::Extensions::Hanami::Router::Trie::Extension,
  gem: "hanami-router",
  version: "3.0.0",
  reason: "the trie caches the segments of every path it looks up and never lets them go",
  upstream: "https://github.com/hanami/hanami-router/issues/310",
)
