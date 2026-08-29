# auto_register: false
# frozen_string_literal: true

module MCP
  module Protocol
    class ScopedServer < Server
      RECONNECT = "%s needs the %s permission, and this connection was never granted it. " \
                  "Connect the app again to grant it"

      def initialize(scopes:, tools: [], **)
        @withheld = tools.reject { scopes.include?(it.scope_value) }.to_h { [it.name_value, it] }

        super(tools: tools - @withheld.values, **)
      end

      private

      def call_tool(request, **)
        withheld = @withheld[request[:name]]
        return super unless withheld

        raise RequestHandlerError.new(
          format(RECONNECT, withheld.name_value, withheld.scope_value), request, error_type: :invalid_params,
        )
      end
    end
  end
end
