# frozen_string_literal: true

module MCP
  module Queries
    class ConnectedClients
      include Deps[client_repo: "repos.oauth_client_repo"]

      def call = client_repo.connected
    end
  end
end
