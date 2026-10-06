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
        transaction do
          client = step find(id)
          cut_off(client)
        end
      end

      private

      def cut_off(client)
        code_repo.delete_for_client(client.id)
        token_repo.delete_for_client(client.id)
        client
      end

      def find(id)
        found(client_repo.connected_by_id_for_update(id))
      end
    end
  end
end
