# frozen_string_literal: true

module MCP
  module OAuth
    module Scope
      READ = "read"
      SUGGEST = "suggest"
      WRITE = "write"
      PUBLISH = "publish"
      DELETE = "delete"

      ALL = [READ, SUGGEST, WRITE, PUBLISH, DELETE].freeze
      DEFAULT = [READ].freeze
      SEPARATOR = " "

      module_function

      def granted(requested)
        kept = requested ? ALL & requested.split(SEPARATOR) : []

        kept.empty? ? DEFAULT : kept.freeze
      end
    end
  end
end
