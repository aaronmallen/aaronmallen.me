# frozen_string_literal: true

module Contact
  module Jobs
    class ReapSpamMessages < Blog::ScheduledJob
      include Deps[reap_spam_messages: "operations.reap_spam_messages"]

      def perform = reap_spam_messages.call
    end
  end
end
