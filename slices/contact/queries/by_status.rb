# frozen_string_literal: true

module Contact
  module Queries
    class ByStatus
      include Deps[message_repo: "repos.message_repo"]

      def call(status) = message_repo.by_status(status)
    end
  end
end
