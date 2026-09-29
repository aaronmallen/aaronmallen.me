# frozen_string_literal: true

module Contact
  module Queries
    class ReceivedBetween
      include Deps[message_repo: "repos.message_repo"]

      def call(from:, to:, page:, status: nil) = message_repo.received_between(from:, to:, page:, status:)
    end
  end
end
