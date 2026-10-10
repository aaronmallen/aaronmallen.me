# frozen_string_literal: true

module MCP
  module Operations
    class RevokeClient < Blog::Operation
      include Deps[
        "repos.oauth_client_queries",
        "repos.oauth_code_mutations",
        "repos.oauth_token_mutations",
      ]

      def call(id)
        transaction do
          client = step find(id)
          cut_off(client)
        end
      end

      private

      def cut_off(client)
        oauth_code_mutations.delete_for_client(client.id)
        oauth_token_mutations.delete_for_client(client.id)
        client
      end

      def find(id)
        found(oauth_client_queries.connected_by_id_for_update(id))
      end
    end
  end
end
