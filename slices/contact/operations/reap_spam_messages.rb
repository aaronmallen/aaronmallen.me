# frozen_string_literal: true

module Contact
  module Operations
    class ReapSpamMessages < Operation
      KEEP_FOR = 30 * 24 * 60 * 60

      include Deps[message_repo: "repos.message_repo"]

      def call(at: Time.now) = message_repo.delete_spam_marked_before(at - KEEP_FOR)
    end
  end
end
