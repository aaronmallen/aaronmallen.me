# frozen_string_literal: true

module Contact
  module Queries
    class UnreadMessageCount
      include Deps[message_repo: "repos.message_repo"]

      def call = message_repo.unread_count
    end
  end
end
