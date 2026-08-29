# frozen_string_literal: true

module MCP
  module Operations
    class RevokeClient < Blog::Operation
      include Deps[
        client_repo: "repos.oauth_client_repo",
        code_repo: "repos.oauth_code_repo",
        token_repo: "repos.oauth_token_repo",
      ]

      def call(id)
        client = step find(id)

        transaction { cut_off(client) }
      end

      private

      def cut_off(client)
        code_repo.delete_for_client(client.id)
        token_repo.delete_for_client(client.id)
        client
      end

      def find(id)
        client = client_repo.connected_by_id(id)
        client ? Success(client) : Failure(:not_found)
      end
    end
  end
end
