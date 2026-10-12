# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Moderate < Action
        TOASTS = "webmentions_page.toasts"

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        def handle(request, response)
          verdict = Blog::Types::WebmentionModeration[request.params[:verdict]]

          result = moderate_webmention.call(record_id(request), verdict, reason: request.params[:reason])
          settle(response, result, "#{TOASTS}.#{verdict}", back(request))
        end

        private

        def back(request) = back_here(request) || routes.path(:admin_webmentions, status: filter(request))

        def filter(request) = Blog::Types::WebmentionStatusParam[request.params[:status]]
      end
    end
  end
end
