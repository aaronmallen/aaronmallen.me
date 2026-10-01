# frozen_string_literal: true

module Contact
  module Jobs
    class ReapSpamMessages < Blog::Job
      include Deps[reap_spam_messages: "operations.reap_spam_messages"]

      sidekiq_options retry: false

      def perform = reap_spam_messages.call
    end
  end
end
