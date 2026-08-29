# frozen_string_literal: true

module MCP
  module OAuth
    module Resource
      module_function

      def ours?(resource, issuer)
        resource.nil? || [issuer, "#{issuer}#{Slice::RESOURCE_PATH}"].include?(resource.chomp("/"))
      end
    end
  end
end
