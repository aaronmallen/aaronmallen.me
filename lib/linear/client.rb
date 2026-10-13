# frozen_string_literal: true

module Linear
  class Client
    include Blog::CursorPaging
    include Issues
    include History

    PROVIDER = Blog::Types::ServiceProvider["linear"]
    WORKSPACE = "query { organization { id name } }"

    def initialize(transport:)
      @transport = transport
    end

    def account(api_key:)
      workspace = transport.call(api_key).query(WORKSPACE)&.dig("organization")
      raise Error, "Linear sent no workspace" unless workspace

      { account_id: workspace.fetch("id"), label: workspace.fetch("name") }
    end

    def configured? = connections.any?

    def inspect = "#<#{self.class.name}>"

    private

    attr_reader :transport

    def connections = services["repos.connection_queries"].for(PROVIDER)

    def services = Hanami.app.slices[:services]

    def transports = connections.map { transport.call(it.credentials.fetch(:api_key)) }
  end
end
