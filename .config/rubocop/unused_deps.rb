# frozen_string_literal: true

module RuboCop
  module Cop
    module Blog
      class UnusedDeps < Hanami::UnusedDeps
        private

        def each_deps_key(arguments)
          allowed = cop_config.fetch("AllowedNames", [])
          super { |key_node, name| yield key_node, name unless allowed.include?(name) }
        end
      end
    end
  end
end
