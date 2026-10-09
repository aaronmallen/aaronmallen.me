# frozen_string_literal: true

module Record
  module Linear
    class Client
      include Paging
      include Issues
      include History

      Error = Transport::Error
      RateLimited = Transport::RateLimited

      PROVIDER = "linear"
      WORKSPACE = "query { organization { id name } }"

      def initialize(connections:, transport:)
        @connections = connections
        @transport = transport
      end

      def account(api_key:)
        workspace = transport.call(api_key).query(WORKSPACE)&.dig("organization")
        raise Error, "Linear sent no workspace" unless workspace

        { account_id: workspace.fetch("id"), label: workspace.fetch("name") }
      end

      def configured? = connections.for(PROVIDER).any?

      def inspect = "#<#{self.class.name}>"

      private

      attr_reader :connections, :transport

      def transports = connections.for(PROVIDER).map { transport.call(it.credentials.fetch(:api_key)) }
    end
  end
end
