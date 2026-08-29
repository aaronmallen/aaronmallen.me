# frozen_string_literal: true

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

Hanami::Router::Trie.prepend(Blog::Extensions::Hanami::Router::Trie::Extension)
