# frozen_string_literal: true

module Contact
  module Operations
    class ReapSpamMessages
      KEEP_FOR = 30 * 24 * 60 * 60

      include Deps[message_mutations: "repos.message_mutations"]

      def call(at: Time.now) = message_mutations.delete_spam_marked_before(at - KEEP_FOR)
    end
  end
end
