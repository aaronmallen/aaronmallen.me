# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Moderate < Action
        TOASTS = "webmentions_page.toasts"

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        def handle(request, response)
          verdict = Blog::Types::WebmentionModeration[request.params[:verdict]]

          case moderate_webmention.call(record_id(request), verdict, reason: request.params[:reason])
          in Success(_)
            toast(response, "#{TOASTS}.#{verdict}")
            response.redirect_to(routes.path(:admin_webmentions, status: filter(request)))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end

        private

        def filter(request) = Blog::Types::WebmentionStatusParam[request.params[:status]]
      end
    end
  end
end
