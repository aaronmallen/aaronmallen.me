# frozen_string_literal: true

module Contact
  module Queries
    class SnoozedMessages
      include Deps[message_repo: "repos.message_repo"]

      def call = message_repo.snoozed
    end
  end
end
