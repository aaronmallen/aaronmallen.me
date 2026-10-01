# frozen_string_literal: true

module API
  module Queries
    class LiveTokens
      include Deps[token_repo: "repos.api_token_repo"]

      def call = token_repo.live
    end
  end
end
