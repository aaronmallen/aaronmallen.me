# frozen_string_literal: true

module MCP
  module OAuth
    module Scope
      READ = "read"
      SUGGEST = "suggest"
      WRITE = "write"

      ALL = [READ, SUGGEST, WRITE].freeze
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
