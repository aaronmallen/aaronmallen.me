# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      module Moderation
        TOASTS = "webmentions_page.toasts"

        include Dry::Monads[:result]

        def handle(request, response)
          verdict = self.class::VERDICT

          case moderate_webmention.call(record_id(request), verdict)
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
