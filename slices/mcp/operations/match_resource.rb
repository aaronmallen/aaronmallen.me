# frozen_string_literal: true

module MCP
  module Operations
    class MatchResource
      def call(resource, issuer)
        resource.nil? || [issuer, "#{issuer}#{Slice::RESOURCE_PATH}"].include?(resource.chomp("/"))
      end
    end
  end
end
