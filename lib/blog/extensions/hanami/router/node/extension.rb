# frozen_string_literal: true

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

Hanami::Router::Node.prepend(Blog::Extensions::Hanami::Router::Node::Extension)
