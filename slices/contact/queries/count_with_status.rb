# frozen_string_literal: true

module Contact
  module Queries
    class CountWithStatus
      include Deps[message_repo: "repos.message_repo"]

      def call(status) = message_repo.count_with_status(status)
    end
  end
end
