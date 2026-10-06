# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class ModerateWebmention < Action
        TOASTS = "webmentions_page.toasts"

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        def handle(request, response)
          verdict = request.params[:verdict]

          result = moderate_webmention.call(record_id(request), verdict, reason: request.params[:reason])
          settle(response, result, "#{TOASTS}.#{verdict}", routes.path(:admin_inbox))
        end
      end
    end
  end
end
