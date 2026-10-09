# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Destroy < BulkAction
        DELETED = "messages_page.toasts.deleted"

        include Deps[
          "settings",
          delete_message: "contact.operations.delete_message",
          message_queries: "contact.repos.message_queries",
        ]

        def handle(request, response)
          settle(response, delete_message.call(record_id(request)), DELETED, back(request))
        end

        private

        def back(request)
          status = Blog::Types::MessageStatusParam[request.params[:status]]
          page = landing(request) { message_queries.page_by_status(status, it).past_end? }

          routes.path(:admin_messages, status:, **Blog::Structs::Page.query(page))
        end
      end
    end
  end
end
