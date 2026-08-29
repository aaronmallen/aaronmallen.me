# frozen_string_literal: true

module MCP
  module Tools
    module Complaints
      INVALID = "check this field"

      module_function

      def call(errors, messages)
        errors.map { |field, (code)| "#{field}: #{messages.dig(field, code) || INVALID}" }.join("; ")
      end
    end
  end
end
