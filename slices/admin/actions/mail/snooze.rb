# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Snooze < Inbox::Snooze
        private

        def back(request)
          Helpers::MailList.back(routes, Helpers::MailList.from(request.params), thread: record_id(request))
        end

        def kind(_request) = "message"
      end
    end
  end
end
