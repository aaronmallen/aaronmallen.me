# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class RemoveTrustedAuthor < Action
        REMOVED = "webmentions_page.toasts.distrusted"

        include Deps[remove_trusted_author: "social.operations.remove_trusted_author"]

        def handle(request, response)
          result = remove_trusted_author.call(request.params[:author_url].to_s)
          settle(response, result, REMOVED, routes.path(:admin_webmention_settings))
        end
      end
    end
  end
end
