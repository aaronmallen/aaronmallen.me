# frozen_string_literal: true

module MCP
  module Operations
    class ReapExpiredCredentials < Blog::Operation
      IDLE_FOR = 90 * 24 * 60 * 60

      include Deps[
        client_repo: "repos.oauth_client_repo",
        code_repo: "repos.oauth_code_repo",
        token_repo: "repos.oauth_token_repo",
      ]

      def call(at: Time.now)
        expired = code_repo.delete_expired(at:) + token_repo.delete_expired(at:)
        expired + client_repo.delete_idle(since: at - IDLE_FOR, at:)
      end
    end
  end
end
