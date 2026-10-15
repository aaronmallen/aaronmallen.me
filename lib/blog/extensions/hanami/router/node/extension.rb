# frozen_string_literal: true

require "blog/extensions"
require "hanami/router"

module Blog
  module Extensions
    module Hanami
      module Router
        module Node
          module Extension
            def capture(path)
              @leaves&.each do |leaf|
                match = leaf.matcher.match(path)
                return [leaf.to, match.named_captures] if match
              end

              nil
            end
          end
        end
      end
    end
  end
end

Blog::Extensions.apply(
  Hanami::Router::Node,
  Blog::Extensions::Hanami::Router::Node::Extension,
  gem: "hanami-router",
  version: "3.0.0",
  reason: "a leaf keeps the params of its last match on itself, which threads serving requests at once share",
  upstream: nil,
)
