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
          settle(response, result, "#{TOASTS}.#{verdict}", routes.path(:admin_webmentions, status: filter(request)))
        end

        private

        def filter(request) = Blog::Types::WebmentionStatusParam[request.params[:status]]
      end
    end
  end
end
