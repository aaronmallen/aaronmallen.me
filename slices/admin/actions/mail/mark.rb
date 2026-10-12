# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Mark < Action
        TOASTS = Blog::Types::MessageStatus.values.to_h { [it, "mail_page.toasts.#{it}"] }.freeze

        include Deps[mark_message: "mail.operations.mark_message"]

        def handle(request, response)
          status = request.params[:status]
          id = record_id(request)

          result = mark_message.call(id, status)
          settle(response, result, TOASTS.fetch(status), Helpers::MailList.back(routes, list(request), thread: id))
        end

        private

        def list(request) = Helpers::MailList.from(request.params)
      end
    end
  end
end
