# frozen_string_literal: true

module MCP
  module Operations
    class ReapExpiredCredentials
      DAY = 24 * 60 * 60
      IDLE_FOR = 90 * DAY
      UNCLAIMED_FOR = DAY

      include Deps[
        "repos.oauth_client_mutations",
        "repos.oauth_code_mutations",
        "repos.oauth_token_mutations",
      ]

      def call(at: Time.now)
        expired = oauth_code_mutations.delete_expired(at:) + oauth_token_mutations.delete_expired(at:)
        expired + oauth_client_mutations.delete_idle(since: at - IDLE_FOR, at:) +
          oauth_client_mutations.delete_unclaimed(since: at - UNCLAIMED_FOR)
      end
    end
  end
end
