# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Snooze < Inbox::Snooze
        include Redirect
        include Deps[thread_queries: "mail.repos.thread_queries"] # rubocop:disable Hanami/UnusedDeps

        private

        def back(request) = listed(request, thread: record_id(request))

        def kind(_request) = "message"
      end
    end
  end
end
