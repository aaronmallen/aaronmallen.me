# auto_register: false
# frozen_string_literal: true

module MCP
  module Protocol
    class ScopedServer < Server
      RECONNECT = "%s needs the %s permission, and this connection was never granted it. " \
                  "Connect the app again to grant it"

      def initialize(scopes:, descriptions: {}, tools: [], **)
        @descriptions = descriptions
        @scopes = scopes
        @withheld = tools.select { missing(it).any? }.to_h { [it.name_value, it] }

        super(tools: tools - @withheld.values, **)
      end

      private

      def call_tool(request, **)
        withheld = @withheld[request[:name]]
        return super unless withheld

        raise RequestHandlerError.new(
          format(RECONNECT, withheld.name_value, missing(withheld).join(" and ")), request, error_type: :invalid_params,
        )
      end

      def list_tools(request)
        super.tap do |listed|
          listed[:tools].each { |tool| tool[:description] = @descriptions.fetch(tool[:name], tool[:description]) }
        end
      end

      def missing(tool) = tool.scope_value - @scopes
    end
  end
end
