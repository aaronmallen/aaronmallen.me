# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Open < BulkAction
        READ = Blog::Types::MessageStatus["read"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        include Deps[
          "settings",
          mark_message: "contact.operations.mark_message",
          message_queries: "contact.repos.message_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          message = message_queries.by_id(id) || halt(404)
          halt 500 if message.status == UNREAD && mark_message.call(id, READ).failure?

          response.redirect_to(back(request, id))
        end

        private

        def back(request, id)
          status = Blog::Types::MessageStatusParam[request.params[:status]]
          page = landing(request) { message_queries.page_by_status(status, it).past_end? }

          "#{routes.path(:admin_messages, status:, **Blog::Structs::Page.query(page), open: id)}#read-#{id}"
        end
      end
    end
  end
end
