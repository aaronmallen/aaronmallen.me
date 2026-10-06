# frozen_string_literal: true

module Contact
  module Queries
    class CountsReceivedBetween
      include Deps[message_repo: "repos.message_repo"]

      def call(from:, to:) = message_repo.count_received_between(from:, to:)
    end
  end
end
