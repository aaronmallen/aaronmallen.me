# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class ModerateWebmention < Action
        TOASTS = "webmentions_page.toasts"

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        def handle(request, response)
          verdict = request.params[:verdict]

          case moderate_webmention.call(record_id(request), verdict, reason: request.params[:reason])
          in Success(_)
            toast(response, "#{TOASTS}.#{verdict}")
            response.redirect_to(routes.path(:admin_inbox))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
