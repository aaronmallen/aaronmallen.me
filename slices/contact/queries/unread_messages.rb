# frozen_string_literal: true

module Contact
  module Queries
    class UnreadMessages
      include Deps[message_repo: "repos.message_repo"]

      def call = message_repo.by_status(Repos::MessageRepo::UNREAD)
    end
  end
end
