# frozen_string_literal: true

module MCP
  module Operations
    class ReapExpiredCredentials < Blog::Operation
      include Deps[code_repo: "repos.oauth_code_repo", token_repo: "repos.oauth_token_repo"]

      def call(at: Time.now) = code_repo.delete_expired(at:) + token_repo.delete_expired(at:)
    end
  end
end
